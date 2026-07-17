require "db"

# Rules engine V2 -- materialized collection maintenance.
#
# A `Rules::View` is a derived collection kept equal to its membership
# query by `Rules::Maintainer`. A view supplies a membership query
# (whose last column is each member's position) and a projection from a
# changed base fact to the affected keys. The maintainer's algorithm is
# identical across every view.
#
module Rules
  abstract class View
    # Identifies one materialized row.
    #
    alias Key = NamedTuple(from_iri: String, to_iri: String)

    # The relationship subtype this view materializes.
    #
    abstract def type : String

    # The membership query, plus its bind arguments.
    #
    # The query selects rows of `(from_iri, to_iri, position)`. A
    # `key` of `nil` returns the full set (the batch reconcile);
    # otherwise it returns the form scoped to a single member.
    #
    abstract def membership(key : Key? = nil) : {String, Array(DB::Any)}

    # Maps a changed base fact to the collection key(s).
    #
    abstract def project(object_iri : String) : Array(Key)

    # The SQL predicate and bind arguments identifying the stored rows
    # that belong to a scope `key`, used to bound the scoped
    # reconcile's delete.
    #
    # Defaults to the identity case.
    #
    def stored_scope(key : Key) : {String, Array(DB::Any)}
      {"from_iri = ? AND to_iri = ?", Array(DB::Any){key[:from_iri], key[:to_iri]}}
    end

    # Whether members reposition on new support (recency views) or
    # stay fixed at first appearance (append-only views).
    #
    def repositions? : Bool
      false
    end

    # The pub/sub subjects to notify when one of `username`'s rows in
    # this view changes.
    #
    # It's empty by default -- the view publishes no real-time
    # updates. Views that do mix in `NotifiesNotifications` or
    # `NotifiesTimeline`.
    #
    def subjects(username : String) : Array(String)
      [] of String
    end

    # Mixed into views whose rows appear in an owner's notifications.
    #
    module NotifiesNotifications
      def subjects(username : String) : Array(String)
        ["/actors/#{username}/notifications"]
      end
    end

    # Mixed into views whose rows appear in an owner's timeline.
    #
    module NotifiesTimeline
      def subjects(username : String) : Array(String)
        ["/actors/#{username}/timeline"]
      end
    end

    @@registry = [] of View

    # All registered views.
    #
    def self.registry : Array(View)
      @@registry
    end

    # Registers a view.
    #
    def self.register(view : View) : Nil
      @@registry << view unless @@registry.any? { |v| v.type == view.type }
    end

    # Unregisters a view.
    #
    def self.unregister(view : View) : Nil
      if (existing = @@registry.find { |v| v.type == view.type })
        @@registry.delete(existing)
      end
    end
  end
end
