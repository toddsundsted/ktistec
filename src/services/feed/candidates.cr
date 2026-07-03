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
    def candidates_for(feed : ::Feed) : Array({ActivityPub::Object, Time})
      query = <<-SQL
        SELECT o.iri, MIN(m.created_at)
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
                AND v.version = ?
           )
         GROUP BY o.iri
      SQL
      rows = Ktistec.database.query_all(
        query,
        Relationship::Content::Inbox.to_s,
        feed.owner_iri,
        ActivityPub::Activity::Create.to_s,
        ActivityPub::Activity::Announce.to_s,
        feed.id,
        feed.version,
        as: {String, Time},
      )
      rows.map { |(iri, arrival)| {ActivityPub::Object.find(iri: iri), arrival} }
    end
  end
end
