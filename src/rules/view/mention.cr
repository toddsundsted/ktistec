require "../view"

module Rules
  abstract class View
    # The mention notification view.
    #
    # There is one row per object that mentions the actor, appended at
    # the object's arrival and never repositioned. The key is the
    # mentioning object; the actor is matched on the mention tag's
    # `href` (the canonical actor id).
    #
    # An object that both replies to a post by the actor and mentions
    # the actor yields only the reply notification, never also a
    # mention.
    #
    class Mention < View
      include NotifiesNotifications

      TYPE     = "Relationship::Content::Notification::Mention"
      INBOX    = "Relationship::Content::Inbox"
      CREATE   = "ActivityPub::Activity::Create"
      ANNOUNCE = "ActivityPub::Activity::Announce"
      UPDATE   = "ActivityPub::Activity::Update"
      MENTION  = "Tag::Mention"

      class_getter instance : Mention { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND t.href = ? AND o.iri = ?"
          args = Array(DB::Any){key[:from_iri], key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT t.href AS from_iri,
                  o.iri AS to_iri,
           o.created_at AS position
            FROM tags t
            JOIN objects o ON o.iri = t.subject_iri
            JOIN accounts c ON c.iri = t.href
           WHERE t.type = '#{MENTION}'
             AND o.attributed_to_iri <> t.href
             AND EXISTS (
               SELECT 1
                 FROM relationships m
                 JOIN activities a ON a.iri = m.to_iri
                WHERE m.from_iri = t.href
                  AND m.type = '#{INBOX}'
                  AND a.object_iri = o.iri
                  AND a.type IN ('#{CREATE}', '#{ANNOUNCE}', '#{UPDATE}')
                  AND a.undone_at IS NULL
             )
             AND NOT EXISTS (
               SELECT 1
                 FROM objects parent
                WHERE parent.iri = o.in_reply_to_iri
                  AND parent.attributed_to_iri = t.href
             )
             #{scope}
        GROUP BY t.href, o.iri
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        rows = Ktistec.database.query_all(<<-SQL, object_iri, as: {String, String})
          SELECT DISTINCT t.href, o.iri
            FROM tags t
            JOIN objects o ON o.iri = t.subject_iri
            JOIN accounts c ON c.iri = t.href
           WHERE t.type = '#{MENTION}'
             AND t.subject_iri = ?
          SQL
        rows.map { |(actor, object)| {from_iri: actor, to_iri: object} }
      end
    end

    register(Mention.instance)
  end
end
