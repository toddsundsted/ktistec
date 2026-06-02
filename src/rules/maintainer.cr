require "db"
require "../framework/database"
require "./view"
require "./view/**" # ameba:disable Ktistec/NoRequireGlob
require "../models/relationship/content/notification/quote"
require "../models/relationship/content/notification/poll/expiry"

module Rules
  # The generic maintainer: one algorithm that keeps every view's
  # stored rows equal to its membership query.
  #
  # Writes are raw SQL (bypassing the ORM) and wrapped in a
  # transaction, so a collection is never observably a transient
  # superset of its query.
  #
  module Maintainer
    extend self

    Log = ::Log.for(self)

    # Rebuilds a view's stored rows to exactly equal its membership query.
    #
    def reconcile(view : View) : Nil
      query, args = view.membership
      apply(view.type, query, args, "1", Array(DB::Any).new)
    end

    # Re-evaluates one key to an insert, delete, or no-op.
    #
    # Fired after a base fact changes.
    #
    def reconcile_for(view : View, key : View::Key) : Nil
      query, args = view.membership(key)
      scope, scope_args = view.stored_scope(key)
      apply(view.type, query, args, scope, scope_args)
    end

    # Inserts the membership rows the scope lacks and deletes the stored
    # rows in scope the membership no longer selects, in one transaction.
    #
    # `query` selects `(from_iri, to_iri, position)`; `scope` bounds the
    # delete to the rows owned by the reconciled key (the whole
    # collection, for the batch path).
    #
    private def apply(type : String, query : String, query_args : Array(DB::Any), scope : String, scope_args : Array(DB::Any)) : Nil
      now = Time.utc
      insert = <<-SQL
        INSERT INTO relationships (created_at, updated_at, type, from_iri, to_iri, confirmed, visible)
        SELECT m.position, ?, '#{type}', m.from_iri, m.to_iri, 1, 1
          FROM (#{query}) AS m
         WHERE NOT EXISTS (
           SELECT 1 FROM relationships x
            WHERE x.type = '#{type}' AND x.from_iri = m.from_iri AND x.to_iri = m.to_iri
         )
      SQL
      delete = <<-SQL
        DELETE FROM relationships
         WHERE type = '#{type}'
           AND (#{scope})
           AND NOT EXISTS (
             SELECT 1 FROM (#{query}) AS m
              WHERE m.from_iri = relationships.from_iri AND m.to_iri = relationships.to_iri
           )
      SQL
      transaction do
        Ktistec.database.exec(insert, args: Array(DB::Any){now} + query_args)
        Ktistec.database.exec(delete, args: scope_args + query_args)
      end
    end

    # Re-evaluates every registered view for a changed object,
    # projecting the object to each view's affected key(s).
    #
    def reconcile_object(object_iri : String) : Nil
      View.registry.each do |view|
        view.project(object_iri).each do |key|
          reconcile_for(view, key)
        end
      end
    end

    # Notifications produced imperatively. The batch reconcile leaves these
    # untouched.
    #
    IMPERATIVE = [
      Relationship::Content::Notification::Quote.to_s,
      Relationship::Content::Notification::Poll::Expiry.to_s,
    ]

    # Classifies a relationship `type` by who maintains it, partitioning the
    # maintained-collection space so the batch reconcile never destroys a
    # row it does not own:
    #
    # - `:registry`   -- a registered view; the batch reconcile owns it.
    # - `:imperative` -- a producer-written event record; left untouched.
    # - `:error`      -- neither.
    #
    def bucket(type : String) : Symbol
      if View.registry.any? { |view| view.type == type }
        :registry
      elsif IMPERATIVE.includes?(type)
        :imperative
      else
        :error
      end
    end

    # Wraps a unit of maintenance in a SQLite SAVEPOINT. A savepoint
    # nests cleanly inside an enclosing transaction.
    #
    private def transaction(&) : Nil
      Ktistec.database.exec("SAVEPOINT rules_maintainer")
      begin
        yield
      rescue ex
        Ktistec.database.exec("ROLLBACK TO rules_maintainer")
        raise ex
      ensure
        Ktistec.database.exec("RELEASE rules_maintainer")
      end
    end
  end
end
