require "./maintainer"
require "../models/activity_pub/activity"
require "../models/activity_pub/activity/announce"
require "../models/activity_pub/activity/dislike"
require "../models/activity_pub/activity/like"
require "../models/activity_pub/activity/undo"
require "../models/activity_pub/actor"

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
      object_iris.each do |object_iri|
        Rules::Maintainer.reconcile_object(object_iri)
      end
    end
  end
end

# re-select representatives when a sender is blocked or unblocked.
ActivityPub::Actor::OBSERVERS.observe(:block) { |actor| Rules::Trigger.reconcile_for_actor(actor) }
ActivityPub::Actor::OBSERVERS.observe(:unblock) { |actor| Rules::Trigger.reconcile_for_actor(actor) }
