require "../framework/controller"
require "../models/activity_pub/activity/follow"
require "../models/task/refresh_actor"

class ActorsController
  include Ktistec::Controller

  skip_auth ["/actors/:username", "/actors/:username/public-posts"]

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end

    actor = account.actor

    ok "actors/actor"
  end

  get "/actors/:username/public-posts" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end

    actor = account.actor

    objects = actor.public_posts(*pagination_params(env))

    ok "actors/public_posts"
  end

  get "/actors/:username/posts" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end
    unless account == env.account
      forbidden
    end

    actor = account.actor

    objects = actor.all_posts(*pagination_params(env))

    ok "actors/posts"
  end

  get "/actors/:username/timeline" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end
    unless account == env.account
      forbidden
    end

    actor = account.actor

    objects = actor.timeline(*pagination_params(env))

    account.update_last_timeline_checked_at.save

    ok "actors/timeline"
  end

  get "/actors/:username/notifications" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end
    unless account == env.account
      forbidden
    end

    actor = account.actor

    activities = actor.notifications(*pagination_params(env))

    account.update_last_notifications_checked_at.save

    ok "actors/notifications"
  end

  get "/remote/actors/:id" do |env|
    id = env.params.url["id"].to_i

    unless (actor = ActivityPub::Actor.find?(id))
      not_found
    end

    ok "actors/remote"
  end

  post "/remote/actors/:id/refresh" do |env|
    id = env.params.url["id"].to_i

    unless (actor = ActivityPub::Actor.find?(id))
      not_found
    end

    unless Task::RefreshActor.exists?(actor.iri)
      Task::RefreshActor.new(source: env.account.actor, actor: actor).schedule
    end

    ok
  end
end
