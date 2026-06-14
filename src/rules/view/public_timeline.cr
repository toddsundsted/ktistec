require "../view"
require "../../ktistec/constants"

module Rules
  abstract class View
    # The public timeline view.
    #
    class PublicTimeline < View
      PUBLIC   = Ktistec::Constants::PUBLIC
      TYPE     = "Relationship::Content::PublicTimeline"
      OUTBOX   = "Relationship::Content::Outbox"
      CREATE   = "ActivityPub::Activity::Create"
      ANNOUNCE = "ActivityPub::Activity::Announce"

      class_getter instance : PublicTimeline { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND a.object_iri = ?"
          args = Array(DB::Any){key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT
               '#{PUBLIC}' AS from_iri,
              a.object_iri AS to_iri,
            MIN(r.created_at) AS position
            FROM relationships r
            JOIN accounts c ON c.iri = r.from_iri
            JOIN activities a ON a.iri = r.to_iri
            JOIN objects o ON o.iri = a.object_iri
           WHERE r.type = '#{OUTBOX}'
             AND a.type IN ('#{CREATE}', '#{ANNOUNCE}')
             AND a.undone_at IS NULL
             AND o.in_reply_to_iri IS NULL
             #{scope}
        GROUP BY a.object_iri
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        [{from_iri: PUBLIC, to_iri: object_iri}]
      end
    end

    register(PublicTimeline.instance)
  end
end
