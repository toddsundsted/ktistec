{% if flag?(:with_mastodon_api) %}
  require "../framework/controller"
  require "../models/activity_pub/object"
  require "../models/activity_pub/activity/create"
  require "../services/oauth2/client_registration"
  require "../services/object_factory"
  require "../services/outbox_activity_processor"
  require "../api/serializers/application"
  require "../api/serializers/instance"
  require "../api/serializers/account"
  require "../api/serializers/status"

  class APIController
    include Ktistec::Controller

    Log = ::Log.for("api")

    skip_auth ["/api/*"], OPTIONS
    skip_auth ["/api/v1/apps"], POST
    skip_auth ["/api/v1/instance", "/api/v2/instance", "/api/v1/instance/translation_languages"], GET

    before_all "/api/*" do |env|
      env.response.headers.add("Access-Control-Allow-Origin", "*")
      env.response.content_type = "application/json"
    end

    options "/api/*" do |env|
      env.response.headers.add("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
      env.response.headers.add("Access-Control-Allow-Headers", "Authorization, Content-Type")

      no_content
    end

    post "/api/v1/apps" do |env|
      client_name : String
      redirect_uris : Array(String)
      scopes : String
      website : String?

      content_type = env.request.headers["Content-Type"]?.try(&.split(";").first.strip)

      if content_type == "application/json"
        body = env.request.body.try(&.gets_to_end) || ""
        begin
          json = JSON.parse(body)
        rescue JSON::ParseException
          Log.debug { "Invalid JSON" }
          bad_request "Invalid JSON"
        end

        client_name = json["client_name"]?.try(&.as_s?) || ""

        redirect_uris_raw = json["redirect_uris"]?
        redirect_uris =
          if redirect_uris_raw
            if (as_string = redirect_uris_raw.as_s?)
              [as_string]
            elsif (as_array = redirect_uris_raw.as_a?)
              as_array.compact_map(&.as_s?)
            else
              [] of String
            end
          else
            [] of String
          end

        scopes = json["scopes"]?.try(&.as_s?) || "read"
        website = json["website"]?.try(&.as_s?)
      else
        params = env.params.body

        client_name = params["client_name"]?.try(&.as(String)) || ""

        redirect_uris_raw = params["redirect_uris"]?
        redirect_uris =
          if redirect_uris_raw.is_a?(String)
            [redirect_uris_raw]
          else
            [] of String
          end

        scopes = params["scopes"]? || "read"
        website = params["website"]?
      end

      Log.trace { "apps[POST]: client_name=#{client_name}, redirect_uris=#{redirect_uris}, scopes=#{scopes}" }

      result = OAuth2::ClientRegistration.register(
        client_name: client_name,
        redirect_uris: redirect_uris,
        scopes: scopes,
      )

      case result
      in OAuth2::ClientRegistration::Success
        client = result.client
        app = API::V1::Serializers::Application.from_client(client, include_secret: true, website: website)
        app.to_json
      in OAuth2::ClientRegistration::Failure
        Log.debug { result.error }
        unprocessable_entity "api/error", error: result.error
      end
    end

    get "/api/v1/instance" do |env|
      API::V1::Serializers::Instance.current.to_json
    end

    get "/api/v2/instance" do |env|
      API::V2::Serializers::Instance.current.to_json
    end

    get "/api/v1/accounts/verify_credentials" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      API::V1::Serializers::Account.from_account(account, account.actor, include_source: true).to_json
    end

    get "/api/v1/timelines/home" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      params = cursor_pagination_params(env)
      params = params.merge(limit: params[:limit].clamp(1, 40))

      timeline = account.actor.timeline(**params)
      statuses = timeline.map do |entry|
        API::V1::Serializers::Status.from_object(entry.object)
      end

      if (link = link_header("/api/v1/timelines/home", statuses, params[:limit]))
        env.response.headers["Link"] = link
      end

      statuses.to_a.to_json
    end

    get "/api/v1/timelines/public" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      params = cursor_pagination_params(env)
      params = params.merge(limit: params[:limit].clamp(1, 40))

      posts = ActivityPub::Object.federated_posts(**params)
      statuses = posts.map do |object|
        API::V1::Serializers::Status.from_object(object)
      end

      if (link = link_header("/api/v1/timelines/public", statuses, params[:limit]))
        env.response.headers["Link"] = link
      end

      statuses.to_a.to_json
    end

    get "/api/v1/statuses/:id" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      id = env.params.url["id"].to_i64

      unless (object = ActivityPub::Object.find?(id))
        not_found "api/error", error: "Record not found"
      end

      API::V1::Serializers::Status.from_object(object).to_json
    end

    get "/api/v1/statuses/:id/context" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      id = env.params.url["id"].to_i64

      unless (object = ActivityPub::Object.find?(id))
        not_found "api/error", error: "Record not found"
      end

      ancestors = object.ancestors.reject(&.id.== object.id).map do |ancestor|
        API::V1::Serializers::Status.from_object(ancestor)
      end

      descendants = object.descendants.reject(&.id.== object.id).map do |descendant|
        API::V1::Serializers::Status.from_object(descendant)
      end

      {ancestors: ancestors, descendants: descendants}.to_json
    end

    post "/api/v1/statuses" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      params = normalize_params(env.params.body.presence || env.params.json)

      unless (status_text = params["status"]?.try(&.as(String)).presence)
        unprocessable_entity "api/error", error: "Status can't be blank"
      end

      if (in_reply_to_id = params["in_reply_to_id"]?.try(&.as(String)).presence)
        unless (in_reply_to = ActivityPub::Object.find?(in_reply_to_id.to_i64))
          unprocessable_entity "api/error", error: "Reply not found"
        end
        in_reply_to_iri = in_reply_to.iri
      end

      # map mastodon visibility to ktistec visibility
      visibility =
        case params["visibility"]?.try(&.as(String))
        when "public", "unlisted"
          "public"
        when "private"
          "private"
        when "direct"
          "direct"
        else
          "public"
        end

      build_params = {} of String => String
      build_params["content"] = status_text
      build_params["media-type"] = "text/markdown"
      build_params["visibility"] = visibility
      build_params["sensitive"] = params["sensitive"]?.try(&.as(String)) || "false"
      if (spoiler_text = params["spoiler_text"]?.try(&.as(String)))
        build_params["summary"] = spoiler_text
      end
      if (language = params["language"]?.try(&.as(String)))
        build_params["language"] = language
      end
      if in_reply_to_iri
        build_params["in-reply-to"] = in_reply_to_iri
      end

      result = ObjectFactory.build_from_params(build_params, account.actor)
      object = result.object

      unless result.valid?
        errors = result.errors.map { |field, messages| "#{field}: #{messages.join(", ")}" }.join("; ")
        unprocessable_entity "api/error", error: errors
      end

      activity = ActivityPub::Activity::Create.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        visible: object.visible,
        to: object.to,
        cc: object.cc,
        audience: object.audience,
      )

      unless activity.valid_for_send?
        unprocessable_entity "api/error", error: "Activity is not valid"
      end

      now = Time.utc
      object.assign(published: now)
      activity.assign(published: now)

      activity.save

      OutboxActivityProcessor.process(account, activity)

      API::V1::Serializers::Status.from_object(object).to_json
    end

    # stub endpoints to prevent 404 errors during client initialization

    get "/api/v1/instance/translation_languages" do |env|
      "{}"
    end

    get "/api/v1/filters" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      "[]"
    end

    get "/api/v2/filters" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      "[]"
    end

    get "/api/v1/markers" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      "{}"
    end

    get "/api/v2/notifications/policy" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      {
        for_not_following:    "accept",
        for_not_followers:    "accept",
        for_new_accounts:     "accept",
        for_private_mentions: "accept",
        for_limited_accounts: "filter",
        summary:              {
          pending_requests_count:      0,
          pending_notifications_count: 0,
        },
      }.to_json
    end

    get "/api/v1/notifications" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      "[]"
    end
  end
{% end %}
