require "../framework/controller"
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

    objects = actor.public_posts(**pagination_params(env))

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

    objects = actor.all_posts(**pagination_params(env))

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

    timeline = actor.timeline(**pagination_params(env))

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

    notifications = actor.notifications(**pagination_params(env))

    account.update_last_notifications_checked_at.save

    ok "actors/notifications"
  end

  get "/actors/:username/drafts" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end
    unless account == env.account
      forbidden
    end

    drafts = account.actor.drafts(**pagination_params(env))

    ok "objects/index"
  end

  get "/remote/actors/:id" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    ok "actors/remote"
  end

  post "/remote/actors/:id/block" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    actor.block

    redirect back_path
  end

  post "/remote/actors/:id/unblock" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    actor.unblock

    redirect back_path
  end

  post "/remote/actors/:id/refresh" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    unless Task::RefreshActor.exists?(actor.iri)
      Task::RefreshActor.new(source: env.account.actor, actor: actor).schedule
    end

    ok
  end
end
