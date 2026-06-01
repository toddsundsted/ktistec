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

    # Whether members reposition on new support (recency views) or
    # stay fixed at first appearance (append-only views).
    #
    def repositions? : Bool
      false
    end

    @@registry = [] of View

    # All registered views.
    #
    def self.registry : Array(View)
      @@registry
    end

    # Registers a view.
    #
    def self.register(view : View) : View
      @@registry << view unless @@registry.includes?(view)
      view
    end
  end
end
