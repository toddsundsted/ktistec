require "../../models/feed"
require "../../models/activity_pub"
require "../../models/activity_pub/object"
require "../../models/activity_pub/activity/create"
require "../../models/activity_pub/activity/announce"
require "../../models/relationship/content/inbox"

class Feed
  # The candidate source.
  #
  # The universe of posts eligible to be judged for a feed.
  #
  module Candidates
    extend self

    # Returns the feed's candidates, each with its arrival time.
    #
    # `limit` bounds the candidates to the most recently arrived;
    # `nil` (the default) means unbounded.
    #
    def candidates_for(feed : ::Feed, limit : Int32? = nil) : Array({ActivityPub::Object, Time})
      if limit && limit < 1
        raise ArgumentError.new("limit must be positive")
      end
      query = <<-SQL
        SELECT o.iri, MIN(m.created_at) AS arrival
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
         GROUP BY o.iri
         ORDER BY arrival DESC
         LIMIT ?
      SQL
      rows = Ktistec.database.query_all(
        query,
        Relationship::Content::Inbox.to_s,
        feed.owner_iri,
        ActivityPub::Activity::Create.to_s,
        ActivityPub::Activity::Announce.to_s,
        feed.id,
        limit || -1, # in SQLite, a negative limit means no limit
        as: {String, Time})
      rows.map { |(iri, arrival)| {ActivityPub::Object.find(iri: iri), arrival} }
    end

    # Returns `object`'s arrival time in the feed owner's inbox.
    #
    # Mirrors the arrival computed by `candidates_for`.
    #
    def arrival_for(feed : ::Feed, object : ActivityPub::Object) : Time?
      query = <<-SQL
        SELECT MIN(m.created_at)
          FROM relationships m
          JOIN activities a ON a.iri = m.to_iri
         WHERE m.type = ?
           AND m.from_iri = ?
           AND a.object_iri = ?
           AND a.type IN (?, ?)
           #{ActivityPub.common_filters(activities: "a")}
      SQL
      Ktistec.database.query_one(
        query,
        Relationship::Content::Inbox.to_s,
        feed.owner_iri,
        object.iri,
        ActivityPub::Activity::Create.to_s,
        ActivityPub::Activity::Announce.to_s,
        as: Time?)
    end
  end
end
