require "uri"

require "../safe/safe_uri"

# Path helpers
#
module Utils::Paths
  # Notes:
  # 1) Path helpers that use other path helpers should do so
  #    explicitly via `Utils::Paths` so that they can be used without
  #    requiring the caller include the `Utils::Paths` module.
  # 2) Macro conditionals should be used to sequester code paths that
  #    require `env` from code paths that do not.
  # 3) All helpers return `::Ktistec::SafeURI`.

  def self.path_id_from_iri(iri : String) : String
    (index = iri.rindex('/')) ? iri[(index + 1)..-1] : iri
  end

  # Returns a `SafeURI` for the `Referer` header, suitable as a
  # `redirect` target.
  #
  def self.back_path_for(env : ::HTTP::Server::Context) : ::Ktistec::SafeURI
    referer = env.request.headers["Referer"]?
    fallback = ::Ktistec::SafeURI.assert_safe("/")
    return fallback if referer.nil? || referer.empty?
    return fallback unless ::Ktistec::Util.safe_url?(referer)
    return fallback if referer.starts_with?("//")
    if ::Ktistec::Util.url_scheme(referer)
      # absolute -- accept only if same-origin
      begin
        uri = ::URI.parse(referer)
        server = ::URI.parse(::Ktistec.host)
      rescue ::URI::Error
        return fallback
      end
      return fallback unless uri.scheme == server.scheme && uri.host == server.host && uri.port == server.port
      path = ::String.build do |io|
        io << (uri.path.presence || "/")
        if (q = uri.query.presence)
          io << '?' << q
        end
        if (f = uri.fragment.presence)
          io << '#' << f
        end
      end
      ::Ktistec::SafeURI.assert_safe(path)
    else
      # relative reference (path-absolute, query-only, fragment-only)
      ::Ktistec::SafeURI.assert_safe(referer)
    end
  end

  macro back_path
    ::Utils::Paths.back_path_for(env)
  end

  macro home_path
    ::Ktistec::SafeURI.assert_safe("/")
  end

  # The empty string -- a relative reference resolving to the current
  # page URL. Used as a fallback href on links whose click is
  # intercepted by the client (e.g., Turbo `data-turbo-action` links).
  #
  macro current_page_path
    ::Ktistec::SafeURI::EMPTY_URI
  end

  # A query-only relative reference (`?#{query}`). Resolves against
  # the current page URL.
  #
  macro query_path(query)
    ::Ktistec::SafeURI.assert_safe("?#{{{query}}}")
  end

  # A fragment-only relative reference (`#{{name}}`). Resolves
  # against the current page URL.
  #
  macro fragment_path(name)
    ::Ktistec::SafeURI.assert_safe("##{{{name}}}")
  end

  # Lifts a path validated by `Account#pinned_collections` into a
  # `SafeURI`. The model setter normalizes and allowlist-validates
  # each entry against a small set of route shapes.
  #
  macro pinned_collection_path(path)
    ::Ktistec::SafeURI.assert_safe({{path}})
  end

  macro everything_path
    ::Ktistec::SafeURI.assert_safe("/everything")
  end

  macro sessions_path
    ::Ktistec::SafeURI.assert_safe("/sessions")
  end

  macro search_path
    ::Ktistec::SafeURI.assert_safe("/search")
  end

  macro settings_path
    ::Ktistec::SafeURI.assert_safe("/settings")
  end

  macro filters_path
    ::Ktistec::SafeURI.assert_safe("/filters")
  end

  macro filter_path(filter = nil)
    {% if filter %}
      ::Ktistec::SafeURI.assert_safe("/filters/#{::URI.encode_path_segment({{filter}}.id.to_s)}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/filters/#{::URI.encode_path_segment(env.params.url["id"])}")
    {% end %}
  end

  macro system_path
    ::Ktistec::SafeURI.assert_safe("/system")
  end

  macro metrics_path
    ::Ktistec::SafeURI.assert_safe("/metrics")
  end

  macro tasks_path
    ::Ktistec::SafeURI.assert_safe("/tasks")
  end

  macro admin_path
    ::Ktistec::SafeURI.assert_safe("/admin")
  end

  macro admin_accounts_path
    ::Ktistec::SafeURI.assert_safe("/admin/accounts")
  end

  macro admin_oauth_clients_path
    ::Ktistec::SafeURI.assert_safe("/admin/oauth/clients")
  end

  macro admin_oauth_tokens_path
    ::Ktistec::SafeURI.assert_safe("/admin/oauth/tokens")
  end

  macro remote_activity_path(activity = nil)
    {% if activity %}
      ::Ktistec::SafeURI.assert_safe("/remote/activities/#{::URI.encode_path_segment({{activity}}.id.to_s)}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/remote/activities/#{::URI.encode_path_segment(env.params.url["id"])}")
    {% end %}
  end

  macro activity_path(activity = nil)
    {% if activity %}
      ::Ktistec::SafeURI.assert_safe("/activities/#{::URI.encode_path_segment(Utils::Paths.path_id_from_iri({{activity}}.iri))}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/activities/#{::URI.encode_path_segment(env.params.url["id"])}")
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
    ::Ktistec::SafeURI.assert_safe("/objects")
  end

  macro remote_object_path(object = nil)
    {% if object %}
      ::Ktistec::SafeURI.assert_safe("/remote/objects/#{::URI.encode_path_segment({{object}}.id.to_s)}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/remote/objects/#{::URI.encode_path_segment(env.params.url["id"])}")
    {% end %}
  end

  macro object_path(object = nil)
    {% if object %}
      ::Ktistec::SafeURI.assert_safe("/objects/#{::URI.encode_path_segment(Utils::Paths.path_id_from_iri({{object}}.iri))}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/objects/#{::URI.encode_path_segment(env.params.url["id"])}")
    {% end %}
  end

  macro remote_thread_path(object = nil, anchor = true)
    {% if anchor %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/thread##{Utils::Paths.anchor({{object}})}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/thread")
    {% end %}
  end

  macro thread_path(object = nil, anchor = true)
    {% if anchor %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.object_path({{object}})}/thread##{Utils::Paths.anchor({{object}})}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.object_path({{object}})}/thread")
    {% end %}
  end

  macro remote_branch_path(object = nil, anchor = true)
    {% if anchor %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/branch##{Utils::Paths.anchor({{object}})}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/branch")
    {% end %}
  end

  macro remote_thread_analysis_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/thread/analysis")
  end

  macro edit_object_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.object_path({{object}})}/edit")
  end

  macro reply_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/reply")
  end

  macro quote_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/quote")
  end

  macro fetch_quote_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/fetch/quote")
  end

  macro fetch_quote_authorization_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/fetch/quote-authorization")
  end

  macro bookmark_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/bookmark")
  end

  macro pin_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/pin")
  end

  macro approve_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/approve")
  end

  macro unapprove_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/unapprove")
  end

  macro block_object_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/block")
  end

  macro unblock_object_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/unblock")
  end

  macro follow_thread_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/follow")
  end

  macro unfollow_thread_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/unfollow")
  end

  macro start_fetch_thread_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/fetch/start")
  end

  macro cancel_fetch_thread_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/fetch/cancel")
  end

  macro object_remote_reply_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.object_path({{object}})}/remote-reply")
  end

  macro object_remote_like_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.object_path({{object}})}/remote-like")
  end

  macro object_remote_share_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.object_path({{object}})}/remote-share")
  end

  macro poll_vote_path(question = nil)
    {% if question %}
      ::Ktistec::SafeURI.assert_safe("/polls/#{::URI.encode_path_segment({{question}}.id.to_s)}/vote")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/polls/#{::URI.encode_path_segment(env.params.url["id"])}/vote")
    {% end %}
  end

  macro create_translation_object_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/translation/create")
  end

  macro clear_translation_object_path(object = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_object_path({{object}})}/translation/clear")
  end

  macro remote_actor_path(actor = nil)
    {% if actor %}
      ::Ktistec::SafeURI.assert_safe("/remote/actors/#{::URI.encode_path_segment({{actor}}.id.to_s)}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/remote/actors/#{::URI.encode_path_segment(env.params.url["id"])}")
    {% end %}
  end

  macro actor_path(actor = nil)
    {% if actor %}
      ::Ktistec::SafeURI.assert_safe("/actors/#{::URI.encode_path_segment(Utils::Paths.path_id_from_iri({{actor}}.iri))}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/actors/#{::URI.encode_path_segment(env.params.url["username"])}")
    {% end %}
  end

  macro block_actor_path(actor = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_actor_path({{actor}})}/block")
  end

  macro unblock_actor_path(actor = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_actor_path({{actor}})}/unblock")
  end

  macro refresh_remote_actor_path(actor = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.remote_actor_path({{actor}})}/refresh")
  end

  macro actor_feed_path(actor = nil, feed = nil)
    {% if feed %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.actor_path({{actor}})}/feeds/#{::URI.encode_path_segment({{feed}}.id.to_s)}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.actor_path({{actor}})}/feeds/#{::URI.encode_path_segment(env.params.url["id"])}")
    {% end %}
  end

  macro actor_relationships_path(actor = nil, relationship = nil)
    {% if relationship %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.actor_path({{actor}})}/#{::URI.encode_path_segment({{relationship}})}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.actor_path({{actor}})}/#{::URI.encode_path_segment(env.params.url["relationship"])}")
    {% end %}
  end

  macro actor_bookmarks_path(actor)
    Utils::Paths.actor_relationships_path({{actor}}, "bookmarks")
  end

  macro actor_followers_path(actor)
    Utils::Paths.actor_relationships_path({{actor}}, "followers")
  end

  macro actor_following_path(actor)
    Utils::Paths.actor_relationships_path({{actor}}, "following")
  end

  macro outbox_path(actor = nil)
    Utils::Paths.actor_relationships_path({{actor}}, "outbox")
  end

  macro inbox_path(actor = nil)
    Utils::Paths.actor_relationships_path({{actor}}, "inbox")
  end

  macro actor_remote_follow_path(actor = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.actor_path({{actor}})}/remote-follow")
  end

  macro actor_rss_feed_path(actor = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.actor_path({{actor}})}/feed.rss")
  end

  macro hashtag_path(hashtag = nil)
    {% if hashtag %}
      ::Ktistec::SafeURI.assert_safe("/tags/#{::URI.encode_path_segment({{hashtag}})}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/tags/#{::URI.encode_path_segment(env.params.url["hashtag"])}")
    {% end %}
  end

  macro follow_hashtag_path(hashtag = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.hashtag_path({{hashtag}})}/follow")
  end

  macro unfollow_hashtag_path(hashtag = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.hashtag_path({{hashtag}})}/unfollow")
  end

  macro start_fetch_hashtag_path(hashtag = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.hashtag_path({{hashtag}})}/fetch/start")
  end

  macro cancel_fetch_hashtag_path(hashtag = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.hashtag_path({{hashtag}})}/fetch/cancel")
  end

  macro mention_path(mention = nil)
    {% if mention %}
      ::Ktistec::SafeURI.assert_safe("/mentions/#{::URI.encode_path_segment({{mention}})}")
    {% else %}
      ::Ktistec::SafeURI.assert_safe("/mentions/#{::URI.encode_path_segment(env.params.url["mention"])}")
    {% end %}
  end

  macro follow_mention_path(mention = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.mention_path({{mention}})}/follow")
  end

  macro unfollow_mention_path(mention = nil)
    ::Ktistec::SafeURI.assert_safe("#{Utils::Paths.mention_path({{mention}})}/unfollow")
  end

  macro remote_interaction_path
    ::Ktistec::SafeURI.assert_safe("/remote-interaction")
  end

  macro mcp_user_path(account)
    ::Ktistec::SafeURI.assert_safe("ktistec://users/#{::URI.encode_path_segment({{account}}.id.to_s)}")
  end

  macro mcp_actor_path(actor)
    ::Ktistec::SafeURI.assert_safe("ktistec://actors/#{::URI.encode_path_segment({{actor}}.id.to_s)}")
  end

  macro mcp_object_path(object)
    ::Ktistec::SafeURI.assert_safe("ktistec://objects/#{::URI.encode_path_segment({{object}}.id.to_s)}")
  end

  macro mcp_information_path
    ::Ktistec::SafeURI.assert_safe("ktistec://information")
  end

  macro stream_path(*segments, query = nil)
    ::Ktistec::SafeURI.assert_safe(
      String.build do |%io|
        %io << "/stream"
        {% for segment in segments %}
          %io << '/'
          ::URI.encode_path_segment(%io, ({{segment}}).to_s)
        {% end %}
        {% if query %}
          if (%q = ({{query}})) && !%q.empty?
            %io << '?' << %q
          end
        {% end %}
      end
    )
  end
end
