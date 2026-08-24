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

    # One scanned candidate.
    #
    record Candidate, cursor : Int64, delivered_at : Time, position : Time, object : ActivityPub::Object

    # The candidate predicate, less the floor.
    #
    private PREDICATE_SQL = <<-SQL
           o.published IS NOT NULL
           AND o.special IS NULL
           AND (
             o.visible = 1
             OR EXISTS (
               SELECT 1
                 FROM relationships mbx
                 JOIN activities act ON act.iri = mbx.to_iri
                WHERE mbx.type IN (?, ?)
                  AND mbx.from_iri = ?
                  AND act.object_iri = o.iri
                  AND act.undone_at IS NULL
             )
           )
      SQL

    # The floor. A feed with no floor is unbounded.
    #
    private FLOOR_SQL = "(? IS NULL OR o.created_at > ?)"

    # The rows holding the feed's unjudged candidates.
    #
    private CANDIDATE_ROWS_SQL = <<-SQL
        SELECT m.id, m.created_at, o.created_at, o.iri
          FROM relationships m
          JOIN activities a ON a.iri = m.to_iri
          JOIN objects o ON o.iri = a.object_iri
         WHERE m.type = ?
           AND m.from_iri = ?
           AND a.type IN (?, ?)
           AND #{PREDICATE_SQL}
           AND NOT EXISTS (
             SELECT 1
               FROM feed_verdicts v
              WHERE v.feed_id = ?
                AND v.object_iri = o.iri
           )
      SQL

    private CANDIDATE_ROWS_FROM_NEWEST_SQL = <<-SQL
      #{CANDIDATE_ROWS_SQL}
         ORDER BY m.id DESC
         LIMIT ?
      SQL

    private CANDIDATE_ROWS_BELOW_CURSOR_SQL = <<-SQL
      #{CANDIDATE_ROWS_SQL}
           AND m.id < ?
         ORDER BY m.id DESC
         LIMIT ?
      SQL

    # Returns the rows holding the feed's unjudged candidates, newest
    # first.
    #
    # `cursor` is the mailbox row id to scan down from; `nil` starts at
    # the newest row.
    #
    def candidate_rows_for(feed : ::Feed, cursor : Int64?, limit : Int32) : Array(Candidate)
      if limit < 1
        raise ArgumentError.new("limit must be positive")
      end
      scan(feed, cursor, limit)
    end

    # Returns the feed's candidates, each with its position.
    #
    # `limit` bounds how many rows are scanned; `nil` (the default)
    # scans the whole mailbox.
    #
    def candidates_for(feed : ::Feed, limit : Int32? = nil) : Array({ActivityPub::Object, Time})
      if limit && limit < 1
        raise ArgumentError.new("limit must be positive")
      end
      floor = feed.floor
      seen = Set(String).new
      candidates = [] of {ActivityPub::Object, Time}
      # in SQLite, a negative limit means no limit
      scan(feed, nil, limit || -1).each do |row|
        next unless seen.add?(row.object.iri)
        next if floor && row.position <= floor
        candidates << {row.object, row.position}
      end
      candidates
    end

    private def scan(feed : ::Feed, cursor : Int64?, limit : Int32) : Array(Candidate)
      rows =
        if cursor
          Ktistec.database.query_all(
            CANDIDATE_ROWS_BELOW_CURSOR_SQL,
            *source_parameters(feed),
            cursor,
            limit,
            as: {Int64, Time, Time, String})
        else
          Ktistec.database.query_all(
            CANDIDATE_ROWS_FROM_NEWEST_SQL,
            *source_parameters(feed),
            limit,
            as: {Int64, Time, Time, String})
        end
      rows.map do |(id, delivered_at, position, iri)|
        Candidate.new(id, delivered_at, position, ActivityPub::Object.find(iri: iri, include_deleted: true))
      end
    end

    private def source_parameters(feed : ::Feed)
      {
        Relationship::Content::Inbox.to_s,
        feed.owner_iri,
        ActivityPub::Activity::Create.to_s,
        ActivityPub::Activity::Announce.to_s,
        *predicate_parameters(feed),
        feed.id,
      }
    end

    # Returns `object`'s position in the feed, or `nil` if the object
    # is not a candidate.
    #
    def arrival_for(feed : ::Feed, object : ActivityPub::Object) : Time?
      query = <<-SQL
        SELECT o.created_at
          FROM objects o
         WHERE o.iri = ?
           AND #{PREDICATE_SQL}
           AND #{FLOOR_SQL}
      SQL
      Ktistec.database.query_one?(
        query,
        object.iri,
        *predicate_parameters(feed),
        feed.floor,
        feed.floor,
        as: Time)
    end

    private def predicate_parameters(feed : ::Feed)
      {
        Relationship::Content::Inbox.to_s,
        Relationship::Content::Outbox.to_s,
        feed.owner_iri,
      }
    end
  end
end
