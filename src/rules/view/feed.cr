require "../view"

module Rules
  abstract class View
    # An algorithmic feed's view.
    #
    # Unlike the singleton views, feeds are runtime-created, so
    # instances are constructed and registered from those rows --
    # never here.
    #
    # An object is a member when it has a verdict for the feed that is
    # `included` and current.
    #
    class Feed < View
      getter feed_id : Int64
      getter owner_iri : String

      def initialize(@feed_id : Int64, @owner_iri : String)
      end

      def type : String
        "Feed::#{@feed_id}"
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND v.object_iri = ?"
          args = Array(DB::Any){@owner_iri, @feed_id, key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any){@owner_iri, @feed_id}
        end
        sql = <<-SQL
          SELECT ? AS from_iri,
                 v.object_iri AS to_iri,
                 v.position AS position
            FROM feed_verdicts v
            JOIN objects o ON o.iri = v.object_iri
           WHERE v.feed_id = ?
             AND v.included = 1
             AND o.deleted_at IS NULL
             #{scope}
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        [{from_iri: @owner_iri, to_iri: object_iri}]
      end

      def subjects(username : String) : Array(String)
        ["/actors/#{username}/feeds/#{@feed_id}"]
      end
    end
  end
end
