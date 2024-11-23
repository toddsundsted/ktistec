require "../framework/controller"
require "../models/task/refresh_actor"

require "../models/relationship/content/follow/hashtag"
require "../models/relationship/content/follow/mention"
require "../models/relationship/content/notification/follow/hashtag"
require "../models/relationship/content/notification/follow/mention"
require "../models/relationship/content/notification/follow/thread"

class ActorsController
  include Ktistec::Controller

  skip_auth ["/actors/:username", "/actors/:username/public-posts"], GET

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end

    actor = account.actor

    ok "actors/actor", env: env, actor: actor
  end

  get "/actors/:username/public-posts" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end

    actor = account.actor

    objects = actor.public_posts(**pagination_params(env))

    ok "actors/public_posts", env: env, actor: actor, objects: objects
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

    ok "actors/posts", env: env, actor: actor, objects: objects
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

    account.update_last_timeline_checked_at

    ok "actors/timeline", env: env, actor: actor, timeline: timeline
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

    account.update_last_notifications_checked_at

    ok "actors/notifications", env: env, account: account, actor: actor, notifications: notifications
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

    ok "objects/index", env: env, drafts: drafts ### wow, should this be called drafts instead of objects?
  end

  get "/remote/actors/:id" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    ok "actors/remote", env: env, actor: actor
  end

  post "/remote/actors/:id/block" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    actor.block!

    redirect back_path
  end

  post "/remote/actors/:id/unblock" do |env|
    unless (actor = ActivityPub::Actor.find?(id_param(env)))
      not_found
    end

    actor.unblock!

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
