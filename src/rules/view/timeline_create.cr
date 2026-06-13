require "../view"

module Rules
  abstract class View
    # The create-kept half of the timeline view.
    #
    # There is one row per object in the actor's timeline, fixed at its
    # first contribution and never repositioned. An object is
    # create-kept when a create (or update) in the actor's mailbox
    # delivered it and at least one of the following holds:
    # - the post is the actor's own (replies included),
    # - the post mentions the actor (replies and mentions of others
    #   don't disqualify it), or
    # - the post is not a reply and has no mentions at all.
    #
    # An object that is both create-kept and announced yields only the
    # create row, never also an announce (see `TimelineAnnounce`).
    #
    class TimelineCreate < View
      include NotifiesTimeline

      TYPE    = "Relationship::Content::Timeline::Create"
      INBOX   = "Relationship::Content::Inbox"
      OUTBOX  = "Relationship::Content::Outbox"
      CREATE  = "ActivityPub::Activity::Create"
      UPDATE  = "ActivityPub::Activity::Update"
      MENTION = "Tag::Mention"

      # The create-kept disjunction. `TimelineAnnounce` embeds it,
      # negated, so that the two timeline views are mutually exclusive
      # by construction. At every embed site, `m` is the qualifying
      # create/update's mailbox row, `a` that activity, and `o` the
      # object (the announce view's subquery aliases shadow its outer
      # announce aliases to guarantee this).
      #
      QUALIFIES = <<-SQL
        (o.in_reply_to_iri IS NULL
         AND NOT EXISTS (
           SELECT 1
             FROM tags t
            WHERE t.type = '#{MENTION}'
              AND t.subject_iri = o.iri
         ))
        OR o.attributed_to_iri = m.from_iri
        OR EXISTS (
          SELECT 1
            FROM tags t
           WHERE t.type = '#{MENTION}'
             AND t.subject_iri = o.iri
             AND t.href = m.from_iri
        )
      SQL

      class_getter instance : TimelineCreate { new }

      def type : String
        TYPE
      end

      def membership(key : Key? = nil) : {String, Array(DB::Any)}
        if key
          scope = "AND m.from_iri = ? AND o.iri = ?"
          args = Array(DB::Any){key[:from_iri], key[:to_iri]}
        else
          scope = ""
          args = Array(DB::Any).new
        end
        sql = <<-SQL
          SELECT m.from_iri AS from_iri,
                      o.iri AS to_iri,
          MIN(m.created_at) AS position
            FROM relationships m
            JOIN accounts c ON c.iri = m.from_iri
            JOIN activities a ON a.iri = m.to_iri
            JOIN objects o ON o.iri = a.object_iri
           WHERE m.type IN ('#{INBOX}', '#{OUTBOX}')
             AND a.type IN ('#{CREATE}', '#{UPDATE}')
             AND a.undone_at IS NULL
             AND o.deleted_at IS NULL
             AND (#{QUALIFIES})
             #{scope}
          GROUP BY m.from_iri, o.iri
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
             AND a.type IN ('#{CREATE}', '#{UPDATE}')
             AND a.object_iri = ?
          SQL
        owners.map { |owner| {from_iri: owner, to_iri: object_iri} }
      end
    end

    register(TimelineCreate.instance)
  end
end
