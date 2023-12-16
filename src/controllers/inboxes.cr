require "../framework/constants"
require "../framework/controller"
require "../framework/open"
require "../framework/signature"
require "../models/activity_pub/activity/**"
require "../models/task/receive"
require "../rules/content_rules"

class RelationshipsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/inbox"], POST

  post "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless (body = env.request.body.try(&.gets_to_end).presence)
      bad_request("Body Is Blank")
    end

    activity =
      begin
        ActivityPub::Activity.from_json_ld(body)
      rescue Ktistec::Model::TypeError
        bad_request("Unsupported Type")
      end

    if activity.local?
      forbidden
    end

    # if the activity is signed but we don't have the actor's public
    # key, 1) fetch the actor, including their public key. 2) verify
    # the activity against the actor's public key (this will fail for
    # relays). if the activity is not signed or verification fails,
    # 3) verify the activity by retrieving it from the origin.
    # finally, 4) ensure the verified activity is associated with the
    # fetched actor.

    # 1

    signature = !!env.request.headers["Signature"]?

    # important: never use/trust credentials in an embedded actor!

    actor = nil

    if (actor_iri = activity.actor_iri)
      unless (actor = ActivityPub::Actor.find?(actor_iri)) && (!signature || actor.pem_public_key)
        actor = ActivityPub::Actor.dereference?(account.actor, actor_iri, ignore_cached: true, include_key: true).try(&.save)
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
        headers = Ktistec::Signature.sign(account.actor, object_iri, method: :get)
        headers["Accept"] = Ktistec::Constants::ACCEPT_HEADER
        response = HTTP::Client.get(object_iri, headers)
        if response.status_code.in?([404, 410])
          verified = true
        end
      end
    end

    unless activity && verified
      bad_request("Can't Be Verified")
    end

    # 4

    actor.up!

    activity.actor = actor

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
      # compatibility with implementations that don't address follows
      deliver_to = [account.iri]
    when ActivityPub::Activity::Accept
      unless activity.object?.try(&.local?)
        bad_request
      end
      unless activity.object.actor == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(actor: account.actor, object: activity.actor))
        bad_request
      end
      # compatibility with implementations that don't address accepts
      deliver_to = [account.iri]
    when ActivityPub::Activity::Reject
      unless activity.object?.try(&.local?)
        bad_request
      end
      unless activity.object.actor == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(actor: account.actor, object: activity.actor))
        bad_request
      end
      # compatibility with implementations that don't address rejects
      deliver_to = [account.iri]
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
        unless (follow = Relationship::Social::Follow.find?(actor: object.actor, object: object.object))
          bad_request
        end
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
        deliver_to = [account.iri]
      elsif (object = ActivityPub::Actor.find?(activity.object_iri))
        unless object == activity.actor
          bad_request
        end
        activity.actor = activity.object = object
        deliver_to = [account.iri]
      else
        bad_request
      end
    else
      bad_request("Activity Not Supported")
    end

    # check to see if the activity already exists and save it -- this
    # should be atomic under fibers but is not thread-safe. this
    # prevents duplicate activities being created if the server
    # receives the same activity multiple times. this can happen in
    # practice because the validation steps above take time and
    # servers acting as relays forward activities they've received,
    # and those activities can arrive while the original activity is
    # being validated.

    if ActivityPub::Activity.find?(activity.iri)
      # mastodon reissues identifiers for accept and reject
      # activities. since these are implemented, here, as idempotent
      # operations, don't respond with conflict.
      unless activity.class.in?([ActivityPub::Activity::Accept, ActivityPub::Activity::Reject])
        conflict
      end
    end

    activity.save

    ContentRules.new.run do
      recipients = [activity.to, activity.cc, deliver_to].flatten.compact.uniq
      recipients.each { |recipient| assert ContentRules::IsRecipient.new(recipient) }
      assert ContentRules::Incoming.new(account.actor, activity)
    end

    # handle side-effects

    case activity
    when ActivityPub::Activity::Follow
      if activity.object == account.actor
        unless Relationship::Social::Follow.find?(actor: activity.actor, object: activity.object)
          Relationship::Social::Follow.new(
            actor: activity.actor,
            object: activity.object,
            visible: false
          ).save(skip_associated: true)
        end
      end
    when ActivityPub::Activity::Accept
      if (follow = Relationship::Social::Follow.find?(actor: activity.object.actor, object: activity.object.object))
        follow.assign(confirmed: true).save
      end
    when ActivityPub::Activity::Reject
      if (follow = Relationship::Social::Follow.find?(actor: activity.object.actor, object: activity.object.object))
        follow.assign(confirmed: false).save
      end
    when ActivityPub::Activity::Undo
      case (object = activity.object)
      when ActivityPub::Activity::Follow
        if (follow = Relationship::Social::Follow.find?(actor: object.actor, object: object.object))
          follow.destroy
        end
      end
      activity.object.undo!
    when ActivityPub::Activity::Delete
      case (object = activity.object?)
      when ActivityPub::Object
        object.delete!
      when ActivityPub::Actor
        object.delete!
      end
    end

    Task::Receive.new(
      receiver: account.actor,
      activity: activity,
      deliver_to: deliver_to
    ).schedule

    ok
  end

  get "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    activities = account.actor.in_inbox(**pagination_params(env), public: env.account? != account)

    ok "relationships/inbox"
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end
end
