require "../../rules/maintainer"

module Ktistec
  module Database
    # The one-time materialized-view cutover.
    #
    # Reconciles every registered view so its stored rows equal its
    # membership query.
    #
    module ReconcileMaterializedViews
      extend self

      Log = ::Log.for(self)

      # Pre-typed base relationship types retired (long) before the
      # materialized-view cutover.
      #
      ORPHAN_TYPES = %w[
        Relationship::Content::Timeline
        Relationship::Content::Notification
      ]

      # Reconciles every registered view, then purges the orphaned base
      # types.
      #
      # Not atomic: each view reconciles under its own savepoint and
      # the orphan deletes run in autocommit. This is operation is
      # idempotent.
      #
      def run(db)
        Rules::View.registry.each do |view|
          before = count(db, view.type)
          Rules::Maintainer.reconcile(view)
          after = count(db, view.type)
          Log.info { "#{view.type}: #{before} -> #{after}" }
        end
        ORPHAN_TYPES.each do |type|
          deleted = db.exec("DELETE FROM relationships WHERE type = ?", type).rows_affected
          Log.info { "#{type}: deleted #{deleted}" }
        end
      end

      private def count(db, type) : Int64
        db.scalar("SELECT COUNT(*) FROM relationships WHERE type = ?", type).as(Int64)
      end
    end
  end
end
