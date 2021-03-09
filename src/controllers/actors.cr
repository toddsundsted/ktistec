require "../framework/controller"
require "../models/activity_pub/activity/follow"
require "../models/task/refresh_actor"

class ActorsController
  include Ktistec::Controller

  skip_auth ["/actors/:username"]

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    actor = Account.find(username: username).actor

    ok "actors/actor"
  rescue Ktistec::Model::NotFound
    not_found
  end

  get "/remote/actors/:id" do |env|
    id = env.params.url["id"].to_i

    actor = ActivityPub::Actor.find(id)

    ok "actors/remote"
  rescue Ktistec::Model::NotFound
    not_found
  end

  post "/remote/actors/:id/refresh" do |env|
    id = env.params.url["id"].to_i

    actor = ActivityPub::Actor.find(id)

    unless Task::RefreshActor.exists?(actor.iri)
      Task::RefreshActor.new(source: env.account.actor, actor: actor).schedule
    end

    ok
  rescue Ktistec::Model::NotFound
    not_found
  end
end
