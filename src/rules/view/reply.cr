require "../view"
require "../../models/relationship/content/notification/reply"
require "../../models/relationship/content/inbox"
require "../../models/activity_pub/activity/create"
require "../../models/activity_pub/activity/announce"
require "../../models/activity_pub/activity/update"
require "../../models/activity_pub/object"
require "../../models/activity_pub/actor"

module Rules
  abstract class View
    # The reply notification view.
    #
    # There is one row per object that replies to a post by the actor,
    # appended at the reply's arrival and never repositioned. The key is
    # the reply object; the actor is the author of the post being
    # replied to.
    #
    class Reply < View
      TYPE     = Relationship::Content::Notification::Reply.to_s
      INBOX    = Relationship::Content::Inbox.to_s
      CREATE   = ActivityPub::Activity::Create.to_s
      ANNOUNCE = ActivityPub::Activity::Announce.to_s
      UPDATE   = ActivityPub::Activity::Update.to_s

      class_getter instance : Reply { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND o.iri = ?"
          args = Array(DB::Any){key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT parent.attributed_to_iri AS from_iri,
                                    o.iri AS to_iri,
                             o.created_at AS position
            FROM objects o
            JOIN objects parent ON parent.iri = o.in_reply_to_iri
            JOIN accounts c ON c.iri = parent.attributed_to_iri
           WHERE o.attributed_to_iri <> parent.attributed_to_iri
             AND EXISTS (
               SELECT 1
                 FROM relationships m
                 JOIN activities a ON a.iri = m.to_iri
                WHERE m.from_iri = parent.attributed_to_iri
                  AND m.type = '#{INBOX}'
                  AND a.object_iri = o.iri
                  AND a.type IN ('#{CREATE}', '#{ANNOUNCE}', '#{UPDATE}')
                  AND a.undone_at IS NULL
             )
             #{scope}
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        rows = Ktistec.database.query_all(<<-SQL, object_iri, as: {String, String})
          SELECT parent.attributed_to_iri, o.iri
            FROM objects o
            JOIN objects parent ON parent.iri = o.in_reply_to_iri
            JOIN accounts c ON c.iri = parent.attributed_to_iri
           WHERE o.iri = ?
          SQL
        rows.map { |(actor, object)| {from_iri: actor, to_iri: object} }
      end
    end
  end
end
