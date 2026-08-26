require "../../models/feed"
require "../../models/activity_pub"
require "../../models/activity_pub/object"
require "../../models/relationship/content/inbox"
require "../../models/relationship/content/outbox"

class Feed
  # The candidate source.
  #
  # The universe of posts eligible to be judged for a feed.
  #
  module Candidates
    extend self

    # The candidate predicate.
    #
    private PREDICATE_SQL = <<-SQL
           published IS NOT NULL
           AND special IS NULL
           AND (
             visible = 1
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

    # The scan.
    #
    private CANDIDATES_SQL = <<-SQL
      #{PREDICATE_SQL}
           AND id > ?
           AND id < ?
           AND NOT EXISTS (
             SELECT 1
               FROM feed_verdicts v
              WHERE v.feed_id = ?
                AND v.object_iri = objects.iri
           )
         ORDER BY id DESC
         LIMIT ?
      SQL

    # Returns the feed's unjudged candidates, newest first.
    #
    # `cursor` is the object id to scan down from; `nil` starts at the
    # newest object. A caller that already knows the floor's id passes
    # it as `floor_id` and the probe is skipped.
    #
    def candidates_for(feed : ::Feed, cursor : Int64? = nil, limit : Int32? = nil, floor_id : Int64? = nil) : Array(ActivityPub::Object)
      if limit && limit < 1
        raise ArgumentError.new("limit must be positive")
      end
      ActivityPub::Object.where(
        CANDIDATES_SQL,
        *predicate_parameters(feed),
        floor_id || floor_id(feed) || 0_i64,
        cursor || Int64::MAX,
        feed.id,
        # in SQLite, a negative limit means no limit
        limit || -1,
        include_deleted: true,
      )
    end

    # Returns the id of the newest object at or below the feed's
    # floor -- the bottom of the scan's window.
    #
    def floor_id(feed : ::Feed) : Int64?
      return unless (floor = feed.floor)
      Ktistec.database.query_one?(
        "SELECT id FROM objects WHERE created_at <= ? ORDER BY id DESC LIMIT 1",
        floor,
        as: Int64)
    end

    # Returns `object`'s position in the feed, or `nil` if the object
    # is not a candidate.
    #
    def arrival_for(feed : ::Feed, object : ActivityPub::Object) : Time?
      query = <<-SQL
        SELECT created_at
          FROM objects
         WHERE iri = ?
           AND #{PREDICATE_SQL}
           AND (? IS NULL OR created_at > ?)
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
