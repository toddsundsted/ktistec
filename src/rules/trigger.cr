require "./maintainer"
require "./view/follow_hashtag"
require "../models/activity_pub/activity"
require "../models/activity_pub/activity/announce"
require "../models/activity_pub/activity/dislike"
require "../models/activity_pub/activity/like"
require "../models/activity_pub/activity/undo"
require "../models/activity_pub/actor"
require "../models/relationship/content/follow/hashtag"
require "../models/tag/hashtag"

module Rules
  # The trigger.
  #
  # Maps a changed activity to the object whose materialized views
  # must be re-evaluated and drives the maintainer.
  #
  module Trigger
    extend self

    # Re-evaluates the materialized views for the object an activity
    # concerns.
    #
    def reconcile_for_activity(activity : ActivityPub::Activity) : Nil
      object_iri =
        if activity.is_a?(ActivityPub::Activity::Undo)
          activity.object?.try(&.object_iri)
        else
          activity.object_iri
        end
      Rules::Maintainer.reconcile_object(object_iri) if object_iri
    end

    # Re-evaluates the materialized views affected by a change to an
    # actor's state.
    #
    def reconcile_for_actor(actor : ActivityPub::Actor) : Nil
      object_iris = Ktistec.database.query_all(<<-SQL, actor.iri, ActivityPub::Activity::Announce.to_s, ActivityPub::Activity::Dislike.to_s, ActivityPub::Activity::Like.to_s, as: String)
        SELECT DISTINCT object_iri
          FROM activities
         WHERE actor_iri = ?
           AND type IN (?, ?, ?)
           AND undone_at IS NULL
           AND object_iri IS NOT NULL
        SQL
      object_iris += Ktistec.database.query_all(<<-SQL, Tag::Hashtag.to_s, Relationship::Content::Follow::Hashtag.to_s, actor.iri, as: String)
        SELECT DISTINCT o.iri
          FROM objects o
          JOIN tags t ON t.subject_iri = o.iri AND t.type = ?
          JOIN relationships f ON f.type = ? AND f.to_iri = t.name
         WHERE o.attributed_to_iri = ?
        SQL
      object_iris.uniq.each do |object_iri|
        Rules::Maintainer.reconcile_object(object_iri)
      end
    end

    # Re-evaluates the hashtag-follow notification for an `(owner, name)`
    # key.
    #
    def reconcile_for_hashtag(owner_iri : String, name : String) : Nil
      key = {from_iri: owner_iri, to_iri: name}
      Rules::Maintainer.reconcile_for(Rules::View::FollowHashtag.instance, key)
    end

    # :ditto:
    def reconcile_for_hashtag_follow(follow : Relationship::Content::Follow::Hashtag) : Nil
      reconcile_for_hashtag(follow.from_iri, follow.name)
    end
  end
end

# re-select representatives when a sender is blocked or unblocked.
ActivityPub::Actor::OBSERVERS.observe(:block) { |actor| Rules::Trigger.reconcile_for_actor(actor) }
ActivityPub::Actor::OBSERVERS.observe(:unblock) { |actor| Rules::Trigger.reconcile_for_actor(actor) }

# evict the hashtag-follow notification when its follow is removed.
Relationship::Content::Follow::Hashtag::OBSERVERS.observe(:destroy) { |follow| Rules::Trigger.reconcile_for_hashtag_follow(follow) }
