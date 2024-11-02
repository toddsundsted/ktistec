require "../framework/controller"

class LookupsController
  include Ktistec::Controller

  get "/lookup/actor" do |env|
    unless (iri = env.params.query["iri"]?.presence)
      bad_request("Invalid Query String")
    end
    unless (actor = ActivityPub::Actor.find?(iri))
      not_found
    end
    redirect remote_actor_path(actor)
  end

  get "/lookup/object" do |env|
    unless (iri = env.params.query["iri"]?.presence)
      bad_request("Invalid Query String")
    end
    unless (object = ActivityPub::Object.find?(iri))
      not_found
    end
    redirect remote_object_path(object)
  end

  get "/lookup/activity" do |env|
    unless (iri = env.params.query["iri"]?.presence)
      bad_request("Invalid Query String")
    end
    unless (activity = ActivityPub::Activity.find?(iri))
      not_found
    end
    redirect remote_activity_path(activity)
  end
end
