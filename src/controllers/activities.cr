require "../framework/controller"

class ActivitiesController
  include Ktistec::Controller

  skip_auth ["/activities/:id"], GET

  # Authorizes activity access.
  #
  # Returns the activity if the user is authorized to view it, `nil`
  # otherwise.
  #
  private def self.get_activity(env, iri_or_id)
    if (activity = ActivityPub::Activity.find?(iri_or_id))
      return activity if activity.visible
      if (account = env.account?)
        return activity if activity.actor_iri == account.iri
        return activity if Relationship::Content::Inbox.find?(owner: account.actor, activity: activity)
      end
    end
  end

  get "/activities/:id" do |env|
    unless (activity = get_activity(env, iri_param(env)))
      not_found
    end

    ok "activities/activity", env: env, activity: activity, recursive: true
  end

  get "/remote/activities/:id" do |env|
    unless (activity = get_activity(env, id_param(env)))
      not_found
    end

    ok "activities/activity", env: env, activity: activity, recursive: true
  end
end
