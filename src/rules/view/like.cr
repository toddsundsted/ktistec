require "../view"

module Rules
  abstract class View
    # The like notification view.
    #
    # There is one row per liked object, holding the latest qualifying
    # like as the object's representative.
    #
    class Like < View
      include NotifiesNotifications

      TYPE   = "Relationship::Content::Notification::Like"
      LIKE   = "ActivityPub::Activity::Like"
      INBOX  = "Relationship::Content::Inbox"
      OUTBOX = "Relationship::Content::Outbox"

      class_getter instance : Like { new }

      def type : String
        TYPE
      end

      def repositions? : Bool
        true
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
          SELECT from_iri, to_iri, position
            FROM (
              SELECT
                  o.attributed_to_iri AS from_iri,
                                a.iri AS to_iri,
                         a.created_at AS position,
                ROW_NUMBER() OVER (
                  PARTITION BY a.object_iri
                      ORDER BY a.created_at DESC, a.id DESC
                ) AS rn
                FROM activities a
                JOIN objects o ON o.iri = a.object_iri
                JOIN accounts c ON c.iri = o.attributed_to_iri
                JOIN actors s ON s.iri = a.actor_iri
               WHERE a.type = '#{LIKE}'
                 AND a.undone_at IS NULL
                 AND s.blocked_at IS NULL
                 AND a.actor_iri <> o.attributed_to_iri
                 AND EXISTS (
                   SELECT 1 FROM relationships m
                    WHERE m.to_iri = a.iri
                      AND m.from_iri = o.attributed_to_iri
                      AND m.type IN ('#{INBOX}', '#{OUTBOX}')
                 )
                 #{scope}
            )
           WHERE rn = 1
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        owner = Ktistec.database.query_one?(<<-SQL, object_iri, as: String)
          SELECT o.attributed_to_iri
            FROM objects o
            JOIN accounts c ON c.iri = o.attributed_to_iri
           WHERE o.iri = ?
          SQL
        owner ? [{from_iri: owner, to_iri: object_iri}] : [] of Key
      end

      def stored_scope(key : Key) : {String, Array(DB::Any)}
        {
          "from_iri = ? AND to_iri IN (SELECT iri FROM activities WHERE type = ? AND object_iri = ?)",
          Array(DB::Any){key[:from_iri], LIKE, key[:to_iri]},
        }
      end
    end

    register(Like.instance)
  end
end
