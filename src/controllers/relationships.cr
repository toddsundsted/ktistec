require "../framework"

class RelationshipsController
  include Balloon::Controller
  extend Balloon::Util

  skip_auth ["/actors/:username/outbox"], GET
  skip_auth ["/actors/:username/inbox"], POST, GET
  skip_auth ["/actors/:username/following"], GET
  skip_auth ["/actors/:username/followers"], GET

  post "/actors/:username/outbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.current_account? == account
      forbidden
    end

    activity = env.params.body

    case activity["type"]?
    when "Follow"
      unless (iri = activity["object"]?) && (object = ActivityPub::Actor.find?(iri))
        bad_request
      end
      activity = ActivityPub::Activity::Follow.new(
        iri: "#{Balloon.host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.iri]
      )
      unless activity.valid_for_send?
        bad_request
      end
      Relationship::Social::Follow.new(
        actor: account.actor,
        object: object
      ).save
    when "Accept"
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity::Follow.find?(iri))
        bad_request
      end
      unless object.object == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
        bad_request
      end
      activity = ActivityPub::Activity::Accept.new(
        iri: "#{Balloon.host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.actor.iri]
      )
      follow.assign(confirmed: true).save
    when "Reject"
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity::Follow.find?(iri))
        bad_request
      end
      unless object.object == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
        bad_request
      end
      activity = ActivityPub::Activity::Reject.new(
        iri: "#{Balloon.host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.actor.iri]
      )
      follow.assign(confirmed: false).save
    when "Undo"
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity::Follow.find?(iri))
        bad_request
      end
      unless object.actor == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
        bad_request
      end
      activity = ActivityPub::Activity::Undo.new(
        iri: "#{Balloon.host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.object.iri]
      )
      follow.destroy
    when "Create"
      unless (content = activity["content"]?)
        bad_request
      end
      activity = ActivityPub::Activity::Create.new(
        iri: "#{Balloon.host}/activities/#{id}",
        actor: account.actor,
        object: ActivityPub::Object::Note.new(
          iri: "#{Balloon.host}/objects/#{id}",
          content: content,
          attributed_to_iri: account.iri,
          published: Time.utc,
          visible: true
        ),
        cc: [account.actor.followers].compact
      )
    else
      bad_request
    end

    Relationship::Content::Outbox.new(
      owner: account.actor,
      activity: activity
    ).save

    Task::Deliver.new(
      sender: account.actor,
      activity: activity
    ).perform

    env.redirect back_path
  end

  post "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless (body = env.request.body)
      bad_request
    end

    activity = ActivityPub::Activity.from_json_ld(body)

    if activity.id
      ok
    end

    # never use an embedded actor's credentials!
    # only trust credentials retrieved from the origin!

    if (actor_iri = activity.actor_iri)
      unless (actor = ActivityPub::Actor.find?(actor_iri)) && (!env.request.headers["Signature"]? || actor.pem_public_key)
        open?(actor_iri) do |response|
          actor = ActivityPub::Actor.from_json_ld?(response.body, include_key: true)
        end
      end
    end

    verified = false

    if env.request.headers["Signature"]?
      if actor && Balloon::Signature.verify?(actor, "#{host}#{env.request.path}", env.request.headers)
        verified = true
      end
    end

    unless verified
      if (activity = ActivityPub::Activity.dereference?(activity.iri))
        verified = true
      end
    end

    unless activity && verified
      bad_request("Can't Be Verified")
    end

    unless actor
      bad_request("Actor Not Present")
    end

    if activity.responds_to?(:actor=)
      activity.actor = actor
    end

    case activity
    when ActivityPub::Activity::Create
      unless (object = activity.object?(dereference: true))
        bad_request
      end
    when ActivityPub::Activity::Follow
      unless actor
        bad_request
      end
      unless (object = activity.object?(dereference: true))
        bad_request
      end
      if account.actor == object
        unless Relationship::Social::Follow.find?(from_iri: actor.iri, to_iri: object.iri)
          Relationship::Social::Follow.new(
            actor: actor,
            object: object
          ).save
        end
      end
    when ActivityPub::Activity::Accept
      unless activity.object?.try(&.local)
        bad_request
      end
      unless activity.object.actor == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: account.actor.iri, to_iri: activity.actor.iri))
        bad_request
      end
      follow.assign(confirmed: true).save
    when ActivityPub::Activity::Reject
      unless activity.object?.try(&.local)
        bad_request
      end
      unless activity.object.actor == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: account.actor.iri, to_iri: activity.actor.iri))
        bad_request
      end
      follow.assign(confirmed: false).save
    when ActivityPub::Activity::Undo
      unless activity.actor?(dereference: true)
        bad_request
      end
      case (object = activity.object?(dereference: true))
      when ActivityPub::Activity::Follow
        unless object.object == account.actor
          bad_request
        end
        unless object.actor == activity.actor
          bad_request
        end
        unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
          bad_request
        end
        follow.destroy
        if [activity.to, activity.cc].compact.flatten.empty?
          activity.to = [account.iri]
        end
      else
        bad_request
      end
    else
      bad_request("Activity Not Supported")
    end

    activity.save

    Task::Deliver.new(
      sender: account.actor,
      activity: activity
    ).perform

    ok
  end

  get "/actors/:username/outbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    activities = account.actor.in_outbox(*pagination_params(env), public: env.current_account? != account)

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/relationships/outbox.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/relationships/outbox.json.ecr"
    end
  end

  get "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    activities = account.actor.in_inbox(*pagination_params(env), public: env.current_account? != account)

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/relationships/inbox.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/relationships/inbox.json.ecr"
    end
  end

  get "/actors/:username/:relationship" do |env|
    unless (account = get_account(env))
      not_found
    end
    actor = account.actor
    unless (related = all_related(env, actor, public: env.current_account? != account))
      bad_request
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/relationships/index.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/relationships/index.json.ecr"
    end
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end

  private def self.pagination_params(env)
    {
      env.params.query["page"]?.try(&.to_i) || 1,
      env.params.query["size"]?.try(&.to_i) || 10
    }
  end

  private def self.all_related(env, actor, public = true)
    case env.params.url["relationship"]?
    when "following"
      actor.all_following(*pagination_params(env), public: public)
    when "followers"
      actor.all_followers(*pagination_params(env), public: public)
    else
    end
  end
end
