require "../view"
require "./timeline_create"
require "../../models/relationship/content/timeline/announce"
require "../../models/relationship/content/inbox"
require "../../models/relationship/content/outbox"
require "../../models/activity_pub/activity/announce"
require "../../models/activity_pub/object"
require "../../models/activity_pub/actor"

module Rules
  abstract class View
    # The announce-kept half of the timeline view.
    #
    # There is one row per object in the actor's timeline, fixed at its
    # first contribution and never repositioned. An object is
    # announce-kept when an announce in the actor's mailbox delivered
    # it (replies included) and it is not create-kept -- the create row
    # wins (see `TimelineCreate::QUALIFIES`), so the two timeline views
    # are mutually exclusive.
    #
    class TimelineAnnounce < View
      TYPE     = Relationship::Content::Timeline::Announce.to_s
      INBOX    = Relationship::Content::Inbox.to_s
      OUTBOX   = Relationship::Content::Outbox.to_s
      CREATE   = ActivityPub::Activity::Create.to_s
      UPDATE   = ActivityPub::Activity::Update.to_s
      ANNOUNCE = ActivityPub::Activity::Announce.to_s

      class_getter instance : TimelineAnnounce { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND ma.from_iri = ? AND o.iri = ?"
          args = Array(DB::Any){key[:from_iri], key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        # the NOT EXISTS aliases its mailbox row `m` and its activity
        # `a`, shadowing the outer announce aliases, so that the names
        # in the embedded `QUALIFIES` resolve to the create-side rows
        # -- exactly what they resolve to in `TimelineCreate`.
        sql = <<-SQL
          SELECT ma.from_iri AS from_iri,
                       o.iri AS to_iri,
          MIN(ma.created_at) AS position
            FROM relationships ma
            JOIN accounts c ON c.iri = ma.from_iri
            JOIN activities a ON a.iri = ma.to_iri
            JOIN objects o ON o.iri = a.object_iri
           WHERE ma.type IN ('#{INBOX}', '#{OUTBOX}')
             AND a.type = '#{ANNOUNCE}'
             AND a.undone_at IS NULL
             AND o.deleted_at IS NULL
             AND NOT EXISTS (
               SELECT 1
                 FROM relationships m
                 JOIN activities a ON a.iri = m.to_iri
                WHERE m.from_iri = ma.from_iri
                  AND m.type IN ('#{INBOX}', '#{OUTBOX}')
                  AND a.object_iri = o.iri
                  AND a.type IN ('#{CREATE}', '#{UPDATE}')
                  AND a.undone_at IS NULL
                  AND (#{TimelineCreate::QUALIFIES})
             )
             #{scope}
          GROUP BY ma.from_iri, o.iri
        SQL
        {sql, args}
      end

      def project(object_iri : String) : Array(Key)
        owners = Ktistec.database.query_all(<<-SQL, object_iri, as: String)
          SELECT DISTINCT m.from_iri
            FROM relationships m
            JOIN accounts c ON c.iri = m.from_iri
            JOIN activities a ON a.iri = m.to_iri
           WHERE m.type IN ('#{INBOX}', '#{OUTBOX}')
             AND a.type = '#{ANNOUNCE}'
             AND a.object_iri = ?
          SQL
        owners.map { |owner| {from_iri: owner, to_iri: object_iri} }
      end
    end

    register(TimelineAnnounce.instance)
  end
end
