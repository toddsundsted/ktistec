require "../framework/controller"
require "../framework/open"
require "../framework/signature"
require "../models/activity_pub/activity/**"
require "../models/task/receive"

class RelationshipsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/inbox"], POST

  post "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless (body = env.request.body.try(&.gets_to_end))
      bad_request
    end

    activity = ActivityPub::Activity.from_json_ld(body)

    if activity.id
      # mastodon reissues identifiers for accept and reject
      # activities. since these are implemented, here, as idempotent
      # operations, don't respond with conflict.
      unless activity.class.in?([ActivityPub::Activity::Accept, ActivityPub::Activity::Reject])
        conflict
      end
    end

    if activity.local?
      forbidden
    end

    # important: never use credentials in an embedded actor!

    # if the activity is signed but we don't have the actor's public
    # key, 1) fetch the actor, including their public key. 2) verify
    # the activity against the actor's public key (this will fail for
    # relays). if the activity is not signed or verification fails,
    # 3) verify the activity by retrieving it from the origin.
    # finally, 4) ensure the verified activity is associated with the
    # fetched actor.

    # 1

    signature = !!env.request.headers["Signature"]?

    if (actor_iri = activity.actor_iri)
      unless (actor = ActivityPub::Actor.find?(actor_iri)) && (!signature || actor.pem_public_key)
        headers = Ktistec::Signature.sign(account.actor, actor_iri, method: :get).merge!(HTTP::Headers{"Accept" => "application/activity+json"})
        Ktistec::Open.open?(actor_iri, headers) do |response|
          actor = ActivityPub::Actor.from_json_ld?(response.body, include_key: true).try(&.save)
        end
      end
    end

    unless actor
      bad_request("Actor Not Present")
    end

    if actor.local?
      forbidden
    end

    verified = false

    # 2

    if signature
      if actor && Ktistec::Signature.verify?(actor, "#{host}#{env.request.path}", env.request.headers, body)
        verified = true
      end
    end

    # 3

    unless verified
      if activity.iri.presence && (temporary = ActivityPub::Activity.dereference?(account.actor, activity.iri))
        activity = temporary
        verified = true
      end
    end

    # mastodon issues identifiers for delete activities that cannot be
    # dereferenced (they are the identifier of the object or actor
    # plus a URL fragment, but the object or actor has been deleted).
    # so as a last resort, when dealing with a delete activity that
    # can't otherwise be verified, check if the deleted object or
    # actor exists, and if it does not (because it has been deleted),
    # consider the activity valid.

    unless verified
      if activity.is_a?(ActivityPub::Activity::Delete) && (object_iri = activity.object_iri)
        response = HTTP::Client.get(object_iri)
        if response.status_code.in?([404, 410])
          verified = true
        end
      end
    end

    unless activity && verified
      bad_request("Can't Be Verified")
    end

    # 4

    if activity.responds_to?(:actor=)
      activity.actor = actor
    end

    case activity
    when ActivityPub::Activity::Announce
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      unless object.attributed_to?(account.actor, dereference: true)
        bad_request
      end
    when ActivityPub::Activity::Like
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      unless object.attributed_to?(account.actor, dereference: true)
        bad_request
      end
      # compatibility with implementations that don't address likes
      deliver_to = [account.iri]
    when ActivityPub::Activity::Create
      unless (object = activity.object?(account.actor, dereference: true, ignore_cached: true))
        bad_request
      end
      unless activity.actor == object.attributed_to?(account.actor, dereference: true)
        bad_request
      end
      object.attributed_to = activity.actor
    when ActivityPub::Activity::Update
      unless (object = activity.object?(account.actor, dereference: true, ignore_cached: true))
        bad_request
      end
      unless activity.actor == object.attributed_to?(account.actor, dereference: true)
        bad_request
      end
      object.attributed_to = activity.actor
    when ActivityPub::Activity::Follow
      unless actor
        bad_request
      end
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      if account.actor == object
        unless Relationship::Social::Follow.find?(from_iri: actor.iri, to_iri: object.iri)
          Relationship::Social::Follow.new(
            actor: actor,
            object: object,
            visible: false
          ).save
        end
      end
      # compatibility with implementations that don't address follows
      deliver_to = [account.iri]
    when ActivityPub::Activity::Accept
      unless activity.object?.try(&.local?)
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
      unless activity.object?.try(&.local?)
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
      unless activity.actor?(account.actor, dereference: true)
        bad_request
      end
      case (object = activity.object?(account.actor, dereference: true))
      when ActivityPub::Activity::Announce, ActivityPub::Activity::Like
        unless object.actor == activity.actor
          bad_request
        end
        deliver_to = [account.iri]
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
        deliver_to = [account.iri]
      else
        bad_request
      end
    when ActivityPub::Activity::Delete
      unless activity.actor?(account.actor, dereference: true)
        bad_request
      end
      # fetch the object from the database because we can't trust the
      # contents of the payload. also because the original object may
      # be replaced by a tombstone (per the spec).
      if (object = ActivityPub::Object.find?(activity.object_iri))
        unless object.attributed_to? == activity.actor
          bad_request
        end
        activity.object = object
        object.delete
      elsif (object = ActivityPub::Actor.find?(activity.object_iri))
        unless object == activity.actor
          bad_request
        end
        activity.actor = activity.object = object
        object.delete
      else
        bad_request
      end
    else
      bad_request("Activity Not Supported")
    end

    activity.save

    task = Task::Receive.new(
      receiver: account.actor,
      activity: activity,
      deliver_to: deliver_to
    )
    if Kemal.config.env == "test"
      task.perform
    else
      task.schedule
    end

    ok
  end

  get "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    activities = account.actor.in_inbox(*pagination_params(env), public: env.account? != account)

    ok "relationships/inbox"
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end
end
