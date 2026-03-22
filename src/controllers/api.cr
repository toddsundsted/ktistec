{% if flag?(:with_mastodon_api) %}
  require "../framework/controller"
  require "../models/activity_pub/object"
  require "../models/activity_pub/object/question"
  require "../models/activity_pub/activity/create"
  require "../models/poll"
  require "../services/oauth2/client_registration"
  require "../services/object_factory"
  require "../services/outbox_activity_processor"
  require "../api/serializers/application"
  require "../api/serializers/instance"
  require "../api/serializers/account"
  require "../api/serializers/status"
  require "../api/serializers/relationship"

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

      actor = account.actor
      params = cursor_pagination_params(env)
      params = params.merge(limit: params[:limit].clamp(1, 40))

      timeline = actor.timeline(**params)
      statuses = timeline.map do |entry|
        API::V1::Serializers::Status.from_object(entry.object, actor: actor)
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

      actor = account.actor
      params = cursor_pagination_params(env)
      params = params.merge(limit: params[:limit].clamp(1, 40))

      posts = ActivityPub::Object.federated_posts(**params)
      statuses = posts.map do |object|
        API::V1::Serializers::Status.from_object(object, actor: actor)
      end

      if (link = link_header("/api/v1/timelines/public", statuses, params[:limit]))
        env.response.headers["Link"] = link
      end

      statuses.to_a.to_json
    end

    get "/api/v1/statuses/:id" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      id = env.params.url["id"].to_i64

      unless (object = ActivityPub::Object.find?(id))
        not_found "api/error", error: "Record not found"
      end

      API::V1::Serializers::Status.from_object(object, actor: account.actor).to_json
    end

    get "/api/v1/statuses/:id/context" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      actor = account.actor
      id = env.params.url["id"].to_i64

      unless (object = ActivityPub::Object.find?(id))
        not_found "api/error", error: "Record not found"
      end

      ancestors = object.ancestors.reject(&.id.== object.id).map do |ancestor|
        API::V1::Serializers::Status.from_object(ancestor, actor: actor)
      end

      descendants = object.descendants.reject(&.id.== object.id).map do |descendant|
        API::V1::Serializers::Status.from_object(descendant, actor: actor)
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

      API::V1::Serializers::Status.from_object(object, actor: account.actor).to_json
    end

    post "/api/v1/statuses/:id/favourite" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (object = ActivityPub::Object.find?(id_param(env)))
        not_found "api/error", error: "Object not found"
      end

      actor = account.actor

      unless actor.find_like_for(object)
        to = [object.attributed_to.iri]
        cc = [actor.followers].compact

        activity = ActivityPub::Activity::Like.new(
          iri: "#{host}/activities/#{id}",
          actor: actor,
          object: object,
          published: Time.utc,
          to: to,
          cc: cc,
        )

        activity.save
        OutboxActivityProcessor.process(account, activity)
      end

      API::V1::Serializers::Status.from_object(object, actor: actor).to_json
    end

    post "/api/v1/statuses/:id/unfavourite" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (object = ActivityPub::Object.find?(id_param(env)))
        not_found "api/error", error: "Object not found"
      end

      actor = account.actor

      if (like = actor.find_like_for(object))
        to = [object.attributed_to.iri]
        cc = [actor.followers].compact

        undo = ActivityPub::Activity::Undo.new(
          iri: "#{host}/activities/#{id}",
          actor: actor,
          object: like,
          to: to,
          cc: cc,
        )

        undo.save
        OutboxActivityProcessor.process(account, undo)
      end

      API::V1::Serializers::Status.from_object(object, actor: actor).to_json
    end

    post "/api/v1/statuses/:id/reblog" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (object = ActivityPub::Object.find?(id_param(env)))
        not_found "api/error", error: "Object not found"
      end

      actor = account.actor

      unless actor.find_announce_for(object)
        to = [Ktistec::Constants::PUBLIC]
        cc = [object.attributed_to.iri, actor.followers].compact

        activity = ActivityPub::Activity::Announce.new(
          iri: "#{host}/activities/#{id}",
          actor: actor,
          object: object,
          published: Time.utc,
          visible: true,
          to: to,
          cc: cc,
        )

        activity.save
        OutboxActivityProcessor.process(account, activity)
      end

      API::V1::Serializers::Status.from_object(object, actor: actor).to_json
    end

    post "/api/v1/statuses/:id/unreblog" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (object = ActivityPub::Object.find?(id_param(env)))
        not_found "api/error", error: "Object not found"
      end

      actor = account.actor

      if (announce = actor.find_announce_for(object))
        to = [object.attributed_to.iri]
        cc = [actor.followers].compact

        undo = ActivityPub::Activity::Undo.new(
          iri: "#{host}/activities/#{id}",
          actor: actor,
          object: announce,
          to: to,
          cc: cc,
        )

        undo.save
        OutboxActivityProcessor.process(account, undo)
      end

      API::V1::Serializers::Status.from_object(object, actor: actor).to_json
    end

    post "/api/v1/statuses/:id/bookmark" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (object = ActivityPub::Object.find?(id_param(env)))
        not_found "api/error", error: "Object not found"
      end

      actor = account.actor

      bookmark = Relationship::Content::Bookmark.find_or_new(actor: actor, object: object)
      bookmark.save if bookmark.new_record?

      API::V1::Serializers::Status.from_object(object, actor: actor).to_json
    end

    post "/api/v1/statuses/:id/unbookmark" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (object = ActivityPub::Object.find?(id_param(env)))
        not_found "api/error", error: "Object not found"
      end

      actor = account.actor

      bookmark = Relationship::Content::Bookmark.find?(actor: actor, object: object)
      bookmark.destroy if bookmark

      API::V1::Serializers::Status.from_object(object, actor: actor).to_json
    end

    get "/api/v1/preferences" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      {
        "posting:default:visibility" => "public",
        "posting:default:sensitive"  => false,
        "posting:default:language"   => account.language,
        "reading:expand:media"       => "default",
        "reading:expand:spoilers"    => false,
      }.to_json
    end

    get "/api/v1/accounts/relationships" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end

      actor = account.actor
      ids = env.params.query.fetch_all("id[]")

      relationships = ids.compact_map do |id|
        if (other = ActivityPub::Actor.find?(id.to_i64))
          API::V1::Serializers::Relationship.from_actors(actor, other)
        end
      rescue ArgumentError
      end

      relationships.to_json
    end

    post "/api/v1/polls/:id/votes" do |env|
      unless (account = env.account?)
        unauthorized "api/error", error: "The access token is invalid"
      end
      unless (poll = Poll.find?(id_param(env)))
        not_found "api/error", error: "Poll not found"
      end

      question = poll.question
      actor = account.actor

      if poll.expired?
        unprocessable_entity "api/error", error: "The poll has already ended"
      end
      if question.attributed_to == actor
        unprocessable_entity "api/error", error: "You cannot vote on your own poll"
      end
      if question.voted_by?(actor)
        unprocessable_entity "api/error", error: "You have already voted on this poll"
      end

      choices = env.params.json["choices"]?
      indices = choices.is_a?(Array) ? choices.map(&.as_i) : [] of Int32

      if indices.empty?
        unprocessable_entity "api/error", error: "No choices provided"
      end
      unless poll.multiple_choice
        if indices.size > 1
          unprocessable_entity "api/error", error: "Poll only allows one choice"
        end
      end

      selected = indices.compact_map do |index|
        poll.options[index]?.try(&.name)
      end

      if selected.size != indices.size
        unprocessable_entity "api/error", error: "Invalid choice index"
      end

      now = Time.utc

      selected.each do |name|
        vote = ActivityPub::Object::Note.new(
          iri: "#{host}/objects/#{id}",
          attributed_to: actor,
          in_reply_to: question,
          name: name,
          content: nil,
          published: now,
          special: "vote",
          to: [question.attributed_to.iri],
          cc: [] of String,
        )
        activity = ActivityPub::Activity::Create.new(
          iri: "#{host}/activities/#{id}",
          actor: actor,
          object: vote,
          published: vote.published,
          to: vote.to,
          cc: vote.cc,
        ).save

        if (closed_at = poll.closed_at)
          if closed_at > now
            unless Task::NotifyPollExpiry.find?(question: question)
              Task::NotifyPollExpiry.new(source_iri: "", question: question).schedule(closed_at)
            end
          end
        end

        OutboxActivityProcessor.process(account, activity)
      end

      API::V1::Serializers::Status.build_poll(question, actor).not_nil!.to_json
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

    get "/api/v1/lists" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      "[]"
    end

    get "/api/v1/followed_tags" do |env|
      unless env.account?
        unauthorized "api/error", error: "The access token is invalid"
      end

      "[]"
    end
  end
{% end %}
