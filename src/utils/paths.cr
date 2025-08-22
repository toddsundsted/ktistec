# Path helpers
#
module Utils::Paths
  # Notes:
  # 1) Path helpers that use other path helpers should do so
  #    explicitly via `Utils::Paths` so that they can be used without
  #    requiring the caller include the `Utils::Paths` module.
  # 2) Macro conditionals should be used to sequester code paths that
  #    require `env` from code paths that do not.

  macro back_path
    env.request.headers.fetch("Referer", "/")
  end

  macro home_path
    "/"
  end

  macro everything_path
    "/everything"
  end

  macro sessions_path
    "/sessions"
  end

  macro search_path
    "/search"
  end

  macro settings_path
    "/settings"
  end

  macro filters_path
    "/filters"
  end

  macro filter_path(filter = nil)
    {% if filter %}
      "/filters/#{{{filter}}.id}"
    {% else %}
      "/filters/#{env.params.url["id"]}"
    {% end %}
  end

  macro system_path
    "/system"
  end

  macro metrics_path
    "/metrics"
  end

  macro tasks_path
    "/tasks"
  end

  macro remote_activity_path(activity = nil)
    {% if activity %}
      "/remote/activities/#{{{activity}}.id}"
    {% else %}
      "/remote/activities/#{env.params.url["id"]}"
    {% end %}
  end

  macro activity_path(activity = nil)
    {% if activity %}
      "/activities/#{{{activity}}.uid}"
    {% else %}
      "/activities/#{env.params.url["id"]}"
    {% end %}
  end

  macro anchor(object = nil)
    {% if object %}
      "object-#{{{object}}.id}"
    {% else %}
      "object-#{env.params.url["id"]}"
    {% end %}
  end

  macro objects_path
    "/objects"
  end

  macro remote_object_path(object = nil)
    {% if object %}
      "/remote/objects/#{{{object}}.id}"
    {% else %}
      "/remote/objects/#{env.params.url["id"]}"
    {% end %}
  end

  macro object_path(object = nil)
    {% if object %}
      "/objects/#{{{object}}.uid}"
    {% else %}
      "/objects/#{env.params.url["id"]}"
    {% end %}
  end

  macro remote_thread_path(object = nil, anchor = true)
    {% if anchor %}
      "#{Utils::Paths.remote_object_path({{object}})}/thread##{Utils::Paths.anchor({{object}})}"
    {% else %}
      "#{Utils::Paths.remote_object_path({{object}})}/thread"
    {% end %}
  end

  macro thread_path(object = nil, anchor = true)
    {% if anchor %}
      "#{Utils::Paths.object_path({{object}})}/thread##{Utils::Paths.anchor({{object}})}"
    {% else %}
      "#{Utils::Paths.object_path({{object}})}/thread"
    {% end %}
  end

  macro edit_object_path(object = nil)
    "#{Utils::Paths.object_path({{object}})}/edit"
  end

  macro reply_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/reply"
  end

  macro approve_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/approve"
  end

  macro unapprove_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/unapprove"
  end

  macro block_object_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/block"
  end

  macro unblock_object_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/unblock"
  end

  macro follow_thread_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/follow"
  end

  macro unfollow_thread_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/unfollow"
  end

  macro start_fetch_thread_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/fetch/start"
  end

  macro cancel_fetch_thread_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/fetch/cancel"
  end

  macro object_remote_reply_path(object = nil)
    "#{Utils::Paths.object_path({{object}})}/remote-reply"
  end

  macro object_remote_like_path(object = nil)
    "#{Utils::Paths.object_path({{object}})}/remote-like"
  end

  macro object_remote_share_path(object = nil)
    "#{Utils::Paths.object_path({{object}})}/remote-share"
  end

  macro create_translation_object_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/translation/create"
  end

  macro clear_translation_object_path(object = nil)
    "#{Utils::Paths.remote_object_path({{object}})}/translation/clear"
  end

  macro remote_actor_path(actor = nil)
    {% if actor %}
      "/remote/actors/#{{{actor}}.id}"
    {% else %}
      "/remote/actors/#{env.params.url["id"]}"
    {% end %}
  end

  macro actor_path(actor = nil)
    {% if actor %}
      "/actors/#{{{actor}}.uid}"
    {% else %}
      "/actors/#{env.params.url["username"]}"
    {% end %}
  end

  macro block_actor_path(actor = nil)
    "#{Utils::Paths.remote_actor_path({{actor}})}/block"
  end

  macro unblock_actor_path(actor = nil)
    "#{Utils::Paths.remote_actor_path({{actor}})}/unblock"
  end

  macro refresh_remote_actor_path(actor = nil)
    "#{Utils::Paths.remote_actor_path({{actor}})}/refresh"
  end

  macro actor_relationships_path(actor = nil, relationship = nil)
    {% if relationship %}
      "#{Utils::Paths.actor_path({{actor}})}/#{{{relationship}}}"
    {% else %}
      "#{Utils::Paths.actor_path({{actor}})}/#{env.params.url["relationship"]}"
    {% end %}
  end

  macro outbox_path(actor = nil)
    Utils::Paths.actor_relationships_path({{actor}}, "outbox")
  end

  macro inbox_path(actor = nil)
    Utils::Paths.actor_relationships_path({{actor}}, "inbox")
  end

  macro actor_remote_follow_path(actor = nil)
    "#{Utils::Paths.actor_path({{actor}})}/remote-follow"
  end

  macro hashtag_path(hashtag = nil)
    {% if hashtag %}
      "/tags/#{{{hashtag}}}"
    {% else %}
      "/tags/#{env.params.url["hashtag"]}"
    {% end %}
  end

  macro follow_hashtag_path(hashtag = nil)
    "#{Utils::Paths.hashtag_path({{hashtag}})}/follow"
  end

  macro unfollow_hashtag_path(hashtag = nil)
    "#{Utils::Paths.hashtag_path({{hashtag}})}/unfollow"
  end

  macro start_fetch_hashtag_path(hashtag = nil)
    "#{Utils::Paths.hashtag_path({{hashtag}})}/fetch/start"
  end

  macro cancel_fetch_hashtag_path(hashtag = nil)
    "#{Utils::Paths.hashtag_path({{hashtag}})}/fetch/cancel"
  end

  macro mention_path(mention = nil)
    {% if mention %}
      "/mentions/#{{{mention}}}"
    {% else %}
      "/mentions/#{env.params.url["mention"]}"
    {% end %}
  end

  macro follow_mention_path(mention = nil)
    "#{Utils::Paths.mention_path({{mention}})}/follow"
  end

  macro unfollow_mention_path(mention = nil)
    "#{Utils::Paths.mention_path({{mention}})}/unfollow"
  end

  macro remote_interaction_path
    "/remote-interaction"
  end

  macro mcp_user_path(account)
    "ktistec://users/#{{{account}}.id}"
  end

  macro mcp_actor_path(actor)
    "ktistec://actors/#{{{actor}}.id}"
  end

  macro mcp_object_path(object)
    "ktistec://objects/#{{{object}}.id}"
  end

  macro mcp_information_path
    "ktistec://information"
  end
end
