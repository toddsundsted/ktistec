require "../framework/controller"
require "../models/task/refresh_actor"
require "../utils/rss"

require "../models/relationship/content/follow/hashtag"
require "../models/relationship/content/follow/mention"
require "../models/relationship/content/notification/follow/hashtag"
require "../models/relationship/content/notification/follow/mention"
require "../models/relationship/content/notification/follow/thread"

class ActorsController
  include Ktistec::Controller

  skip_auth ["/actors/:username", "/actors/:username/public-posts", "/actors/:username/feed.rss"], GET

  get "/actors/:username" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end

    actor = account.actor

    if env.account?
      if env.params.query.has_key?("filters")
        filters = env.params.query.fetch_all("filters").reject(&.empty?)
        if filters.any?
          env.session.string("timeline_filters", filters.join(","))
        else
          env.session.delete("timeline_filters")
          redirect "/actors/#{username}"
        end
      else
        if filters = env.session.string?("timeline_filters")
          unless filters.empty?
            query_string = %Q|filters=#{filters.split(",").join("&filters=")}|
            redirect "/actors/#{username}?#{query_string}"
          end
        end
      end
    end

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

  get "/actors/:username/feed.rss" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end

    actor = account.actor

    objects = actor.public_posts(**pagination_params(env))

    actor_name = actor.display_name
    actor_url = actor.display_link

    env.response.content_type = "application/rss+xml; charset=utf-8"

    Ktistec::RSS.generate_rss_feed(
      objects, actor_name, actor_url,
      "#{actor_name}: RSS Feed"
    )
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

    ok "objects/index", env: env, drafts: drafts
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

    if accepts_turbo_stream?
      id = "actor-#{actor.id}-refresh-button"
      env.response.content_type = "text/vnd.turbo-stream.html"
      String.build do |str|
        str << %(<turbo-stream action="replace" target="#{id}">)
        str << %(<template>)
        str << %(<button class="ui button disabled"><i class="sync loading icon"></i> Refresh</button>)
        str << %(</template>)
        str << %(</turbo-stream>)
      end
    else
      ok
    end
  end
end
