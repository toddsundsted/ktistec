require "./maintainer"
require "../models/activity_pub/activity"
require "../models/activity_pub/activity/undo"

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
  end
end
