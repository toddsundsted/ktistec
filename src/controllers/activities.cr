require "../framework/controller"

class ActivitiesController
  include Ktistec::Controller

  skip_auth ["/activities/:id"], GET

  get "/activities/:id" do |env|
    unless (activity = get_activity(env, iri_param(env)))
      not_found
    end

    recursive = true

    ok "activities/activity"
  end

  get "/remote/activities/:id" do |env|
    unless (activity = get_activity(env, id_param(env)))
      not_found
    end

    recursive = true

    ok "activities/activity"
  end

  private def self.get_activity(env, iri_or_id)
    if (activity = ActivityPub::Activity.find?(iri_or_id))
      if activity.visible
        activity
      elsif activity.to.try(&.includes?(PUBLIC)) || activity.cc.try(&.includes?(PUBLIC))
        activity
      elsif (iri = env.account?.try(&.iri))
        if activity.actor_iri == iri
          activity
        end
      end
    end
  end

  private PUBLIC = "https://www.w3.org/ns/activitystreams#Public"
end
