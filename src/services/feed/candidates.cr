require "../../models/feed"
require "../../models/activity_pub"
require "../../models/activity_pub/object"
require "../../models/activity_pub/activity/create"
require "../../models/activity_pub/activity/announce"
require "../../models/relationship/content/inbox"
require "../../models/relationship/content/outbox"

class Feed
  # The candidate source.
  #
  # The universe of posts eligible to be judged for a feed.
  #
  module Candidates
    extend self

    # One mailbox row: a single delivery of a post to the feed's
    # owner.
    #
    record MailboxRow, id : Int64, created_at : Time, object : ActivityPub::Object

    # The rows holding the feed's unjudged candidates.
    #
    private MAILBOX_ROWS_SQL = <<-SQL
        SELECT m.id, m.created_at, o.iri
          FROM relationships m
          JOIN activities a ON a.iri = m.to_iri
          JOIN objects o ON o.iri = a.object_iri
          JOIN actors c ON c.iri = o.attributed_to_iri
         WHERE m.type = ?
           AND m.from_iri = ?
           AND a.type IN (?, ?)
           #{ActivityPub.common_filters(objects: "o", actors: "c", activities: "a")}
           AND NOT EXISTS (
             SELECT 1
               FROM feed_verdicts v
              WHERE v.feed_id = ?
                AND v.object_iri = o.iri
           )
      SQL

    private MAILBOX_ROWS_FROM_NEWEST_SQL = <<-SQL
      #{MAILBOX_ROWS_SQL}
         ORDER BY m.id DESC
         LIMIT ?
      SQL

    private MAILBOX_ROWS_BELOW_CURSOR_SQL = <<-SQL
      #{MAILBOX_ROWS_SQL}
           AND m.id < ?
         ORDER BY m.id DESC
         LIMIT ?
      SQL

    # Returns the mailbox rows holding the feed's unjudged candidates,
    # newest first.
    #
    # `cursor` is the mailbox row id to scan down from; `nil` starts at
    # the newest row.
    #
    def mailbox_rows_for(feed : ::Feed, cursor : Int64?, limit : Int32) : Array(MailboxRow)
      if limit < 1
        raise ArgumentError.new("limit must be positive")
      end
      scan(feed, cursor, limit)
    end

    # Returns the feed's candidates, each with its arrival time.
    #
    # `limit` bounds how many mailbox rows are scanned; `nil` (the
    # default) scans the whole mailbox.
    #
    def candidates_for(feed : ::Feed, limit : Int32? = nil) : Array({ActivityPub::Object, Time})
      if limit && limit < 1
        raise ArgumentError.new("limit must be positive")
      end
      seen = Set(String).new
      candidates = [] of {ActivityPub::Object, Time}
      # in SQLite, a negative limit means no limit
      scan(feed, nil, limit || -1).each do |row|
        next unless seen.add?(row.object.iri)
        if (arrival = arrival_for(feed, row.object))
          candidates << {row.object, arrival}
        end
      end
      candidates
    end

    private def scan(feed : ::Feed, cursor : Int64?, limit : Int32) : Array(MailboxRow)
      rows =
        if cursor
          Ktistec.database.query_all(
            MAILBOX_ROWS_BELOW_CURSOR_SQL,
            *source_parameters(feed),
            cursor,
            limit,
            as: {Int64, Time, String})
        else
          Ktistec.database.query_all(
            MAILBOX_ROWS_FROM_NEWEST_SQL,
            *source_parameters(feed),
            limit,
            as: {Int64, Time, String})
        end
      rows.map { |(id, created_at, iri)| MailboxRow.new(id, created_at, ActivityPub::Object.find(iri: iri)) }
    end

    private def source_parameters(feed : ::Feed)
      {
        Relationship::Content::Inbox.to_s,
        feed.owner_iri,
        ActivityPub::Activity::Create.to_s,
        ActivityPub::Activity::Announce.to_s,
        feed.id,
      }
    end

    # The candidate predicate.
    #
    # An object is a candidate when it is published, is not special,
    # was created after the feed's floor, and is either visible or was
    # delivered to the feed owner's mailbox. A feed with no floor is
    # unbounded.
    #
    private CANDIDATE_SQL = <<-SQL
             o.published IS NOT NULL
             AND o.special IS NULL
             AND (? IS NULL OR o.created_at > ?)
             AND (
               o.visible = 1
               OR EXISTS (
                 SELECT 1
                   FROM relationships m
                   JOIN activities a ON a.iri = m.to_iri
                  WHERE m.type IN (?, ?)
                    AND m.from_iri = ?
                    AND a.object_iri = o.iri
                    AND a.undone_at IS NULL
               )
             )
      SQL

    # Returns `object`'s position in the feed, or `nil` if the object
    # is not a candidate.
    #
    def arrival_for(feed : ::Feed, object : ActivityPub::Object) : Time?
      query = <<-SQL
        SELECT o.created_at
          FROM objects o
         WHERE o.iri = ?
           AND #{CANDIDATE_SQL}
      SQL
      Ktistec.database.query_one?(
        query,
        object.iri,
        *candidate_parameters(feed),
        as: Time)
    end

    private def candidate_parameters(feed : ::Feed)
      {
        feed.floor,
        feed.floor,
        Relationship::Content::Inbox.to_s,
        Relationship::Content::Outbox.to_s,
        feed.owner_iri,
      }
    end
  end
end
