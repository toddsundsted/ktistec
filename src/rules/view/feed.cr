require "../view"

module Rules
  abstract class View
    # An algorithmic feed's view.
    #
    # Unlike the singleton views, feeds are runtime-created, so
    # instances are constructed and registered from those rows --
    # never here.
    #
    # An object is a member when it is a candidate for the feed and
    # has a verdict for the feed's version that is `included`.
    #
    class Feed < View
      INBOX  = "Relationship::Content::Inbox"
      OUTBOX = "Relationship::Content::Outbox"

      # The candidate predicate, over `objects`. `Feed::Candidates`
      # embeds it too, so membership and candidacy agree by
      # construction. Binds the inbox and outbox types and the feed
      # owner's IRI.
      #
      CANDIDATE_SQL = <<-SQL
           objects.published IS NOT NULL
           AND objects.special IS NULL
           AND (
             objects.visible = 1
             OR EXISTS (
               SELECT 1
                 FROM relationships m
                 JOIN activities a ON a.iri = m.to_iri
                WHERE m.type IN (?, ?)
                  AND m.from_iri = ?
                  AND a.object_iri = objects.iri
                  AND a.undone_at IS NULL
             )
           )
      SQL

      getter feed_id : Int64
      getter owner_iri : String

      def initialize(@feed_id : Int64, @owner_iri : String)
      end

      def type : String
        "Feed::#{@feed_id}"
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        args = Array(DB::Any){@owner_iri, @feed_id, INBOX, OUTBOX, @owner_iri}
        if key
          scope = "AND v.object_iri = ?"
          args << key[:to_iri]
        else
          scope = ""
        end
        sql = <<-SQL
          SELECT ? AS from_iri,
                 v.object_iri AS to_iri,
                 objects.created_at AS position
            FROM feeds f
            JOIN feed_verdicts v ON v.version_id = f.version_id
            JOIN objects ON objects.iri = v.object_iri
           WHERE f.id = ?
             AND v.included = 1
             AND (f.floor IS NULL OR objects.created_at > f.floor)
             AND #{CANDIDATE_SQL}
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
