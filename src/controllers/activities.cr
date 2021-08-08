require "../framework/controller"
require "../views/view_helper"

class ActivitiesController
  include Ktistec::Controller
  include Ktistec::ViewHelper

  skip_auth ["/activities/:id"], GET

  get "/activities/:id" do |env|
    iri = "#{host}/activities/#{env.params.url["id"]}"

    unless (activity = get_activity(env, iri))
      not_found
    end

    recursive = true

    ok "activities/activity"
  end

  get "/remote/activities/:id" do |env|
    id = env.params.url["id"].to_i64

    unless (activity = get_activity(env, id))
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
