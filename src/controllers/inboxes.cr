require "../framework/ext/openssl"
require "../framework/controller"
require "../framework/json_ld"
require "../utils/network"
require "../framework/signature"
require "../ktistec/constants"
require "../models/activity_pub/activity/**" # ameba:disable Ktistec/NoRequireGlob
require "../services/inbox_activity_processor"

class InboxesController
  include Ktistec::Controller

  Log = ::Log.for("inbox")

  MAX_INBOX_REQUEST_BYTES = 1_048_576

  skip_auth ["/actors/:username/inbox"], POST

  # Lightweight `KeyPair` for path-based `keyId` resolution.
  #
  private struct ResolvedKey
    include Ktistec::KeyPair

    getter iri : String

    def initialize(@iri : String, @pem_public_key : String)
    end

    def public_key
      OpenSSL::RSA.new(@pem_public_key, false)
    end

    def private_key
      nil
    end
  end

  # Parses the `keyId` parameter from the `Signature` header.
  #
  # Returns `nil` if the header is missing or malformed.
  #
  private def self.parse_key_id(headers : HTTP::Headers) : String?
    if (signature = headers["Signature"]?)
      signature.split(",", remove_empty: true).each do |part|
        parts = part.split("=", 2)
        next unless parts.size == 2
        if parts[0].strip == "keyId"
          return parts[1].strip.delete('"')
        end
      end
    end
  end

  # Resolves a `keyId` from the `Signature` header to the signer and
  # its verification key.
  #
  # Returns a tuple of the signer's IRI and, when the key is carried
  # in a separate document, a `KeyPair` for verification. Handles
  # three cases:
  #
  # 1. Fragment URI (e.g. "actor_iri#main-key") -- the common case
  #    used by Mastodon, Pleroma, Ktistec, etc. The signer is the base
  #    URL; the caller uses the resolved signer actor as its own
  #    `KeyPair`.
  #
  # 2. Path URI returning an actor stub with nested `publicKey`
  #    (GoToSocial). Fetches the document, extracts key fields from
  #    the nested `publicKey` object.
  #
  # 3. Path URI returning a bare key document with top-level
  #    `publicKeyPem` and `owner`.
  #
  # For cases 2 and 3, the signer is the key's `owner` and the
  # resolved key's id must match the `keyId`. Reconciling the signer
  # against the activity's actor is the caller's responsibility --
  # this method does not cross-check against it.
  #
  # Returns `nil` on any failure.
  #
  private def self.resolve_signer(account, key_id : String, request_id)
    if key_id.includes?("#")
      # case 1: fragment URI
      {key_id.split("#", 2).first, nil}
    else
      # cases 2 & 3: path URI
      accept = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
      response = Ktistec::Network.get?(account.actor, key_id, accept)
      unless response
        Log.warn { "[#{request_id}] failed to fetch key for #{key_id}" }
        return
      end
      json_ld = Ktistec::JSON_LD.expand(JSON.parse(response.body))
      # actor stub with nested publicKey
      pem = Ktistec::JSON_LD.dig?(json_ld, "https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem")
      owner = Ktistec::JSON_LD.dig_id?(json_ld, "https://w3id.org/security#publicKey", "https://w3id.org/security#owner")
      resolved_key_id = Ktistec::JSON_LD.dig_id?(json_ld, "https://w3id.org/security#publicKey")
      # bare key document
      unless pem && owner && resolved_key_id
        pem = Ktistec::JSON_LD.dig?(json_ld, "https://w3id.org/security#publicKeyPem")
        owner = Ktistec::JSON_LD.dig_id?(json_ld, "https://w3id.org/security#owner")
        resolved_key_id = json_ld.dig?("@id").try(&.as_s)
      end
      if pem && owner && resolved_key_id && resolved_key_id == key_id
        {owner, ResolvedKey.new(resolved_key_id, pem)}
      end
    end
  rescue ex
    Log.trace { "[#{request_id}] keyId resolution failed with exception: #{ex.message}" }
  end

  # Finds a cached actor by IRI, or dereferences and saves it.
  #
  private def self.find_or_dereference_actor(account, iri, request_id, require_key)
    return unless iri
    actor = ActivityPub::Actor.find?(iri)
    return actor if actor && (!require_key || actor.pem_public_key)
    ActivityPub::Actor.dereference?(account.actor, iri, ignore_cached: true, include_key: true).try do |dereferenced|
      dereferenced.verify_handle!
      dereferenced.save
    end
  end

  # Authorizes a community-relayed `Delete`.
  #
  private def self.relay_delete_authorized?(account, community, object)
    if (audience = object.audience) && audience.includes?(community.iri) &&
       Relationship::Social::Follow.find?(actor: account.actor, object: community)
      return true
    end
    object_gone_at_origin?(account, object.iri)
  end

  # Returns true if the object is gone (404/410) at its own origin.
  #
  private def self.object_gone_at_origin?(account, iri)
    headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
    Ktistec::Network.get(account.actor, iri, headers)
    false
  rescue Ktistec::Network::NotFoundError
    true
  rescue Ktistec::Network::Error
    # other errors -- treat as not-gone
    false
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end

  post "/actors/:username/inbox" do |env|
    request_id = env.request.object_id

    if Ktistec::Server.shutting_down?
      service_unavailable
    end

    unless (account = get_account(env))
      gone
    end

    cap_request_body env, MAX_INBOX_REQUEST_BYTES

    unless (body = env.request.body.try(&.gets_to_end).presence)
      bad_request("Body Is Blank")
    end

    Log.trace { "[#{request_id}] new post" }

    json_ld = Ktistec::JSON_LD.expand(JSON.parse(body))

    # detect a community-relayed activity.

    inner_ld = relayed_inner_activity(json_ld, request_id)

    activity =
      begin
        ActivityPub::Activity.from_json_ld(inner_ld || json_ld)
      rescue Ktistec::Model::TypeError
        bad_request("Unsupported Type")
      end

    outer_actor_iri =
      if inner_ld
        Ktistec::JSON_LD.dig_id?(json_ld, "https://www.w3.org/ns/activitystreams#actor")
      else
        activity.actor_iri
      end

    Log.debug { "[#{request_id}] activity iri=#{activity.iri}" }

    # this is, strictly speaking, not required because this method
    # should be idempotent, but it avoids a lot of unnecessary work

    if Relationship::Content::Inbox.find?(owner: account.actor, activity: activity)
      ok
    end

    # 1) resolve the keyId from the Signature header to the signer and
    # its verification key. 2) verify the signature against the raw
    # body. 3a) a relayed Delete is authenticated by the relaying
    # community's (Group) Announce signature. 3b) a directly-delivered
    # activity is authenticated when the signer is its own actor.
    # otherwise, verify the activity by 4) retrieving it from its
    # origin, or 5) as a last resort, checking the existence of its
    # object or actor. finally, 6) associate the verified activity
    # with its actor.

    # important: never use/trust credentials in an embedded actor!

    # 1 & 2

    signer = nil

    if (key_id = parse_key_id(env.request.headers)) && (resolved = resolve_signer(account, key_id, request_id))
      signer_iri, resolved_key = resolved
      candidate = find_or_dereference_actor(account, signer_iri, request_id, require_key: resolved_key.nil?)
      key_pair = resolved_key || candidate
      if candidate && key_pair && Ktistec::Signature.verify?(key_pair, "#{host}#{env.request.path}", env.request.headers, body)
        signer = candidate
      else
        Log.trace { "[#{request_id}] signature verification failed" }
      end
    end

    verified = false

    actor = nil

    # the verified relaying community

    via_community = nil

    # 3

    if inner_ld && activity.is_a?(ActivityPub::Activity::Delete)
      if signer && signer.iri == outer_actor_iri && signer.type == "ActivityPub::Actor::Group"
        via_community = signer
        verified = true
      end
      actor = find_or_dereference_actor(account, activity.actor_iri, request_id, require_key: false)
    elsif !inner_ld && signer && outer_actor_iri && signer.iri == outer_actor_iri
      actor = signer
      verified = true
    else
      actor = find_or_dereference_actor(account, activity.actor_iri, request_id, require_key: false)

      # 4

      if activity.iri.presence && (temporary = ActivityPub::Activity.dereference?(account.actor, activity.iri))
        activity = temporary
        verified = true
      else
        Log.trace { "[#{request_id}] fetch from origin failed" }
      end

      # 5: some servers issue identifiers for activities that cannot be
      # dereferenced (they are the identifier of the object or actor
      # plus a URL fragment).  so as a last resort, when dealing with an
      # activity that can't otherwise be verified, check on the object
      # or actor.  if the activity is a create or an update, and the
      # object exists, or the activity is a delete, but the object or
      # actor does not exist, consider the activity verified.

      unless verified
        if (object_iri = activity.object_iri)
          if activity.is_a?(ActivityPub::Activity::Create)
            Log.trace { "[#{request_id}] checking object of create iri=#{object_iri}" }
            if (temporary = ActivityPub::Object.dereference?(account.actor, object_iri, ignore_cached: true))
              activity.object = temporary
              verified = true
            end
          elsif activity.is_a?(ActivityPub::Activity::Update)
            Log.trace { "[#{request_id}] checking object of update iri=#{object_iri}" }
            if (temporary = ActivityPub::Object.dereference?(account.actor, object_iri, ignore_cached: true))
              activity.object = temporary
              verified = true
            end
          elsif activity.is_a?(ActivityPub::Activity::Delete)
            Log.trace { "[#{request_id}] checking object of delete iri=#{object_iri}" }
            verified = true if object_gone_at_origin?(account, object_iri)
          end
        end
      end
    end

    # the relayed-Delete path tolerates an unreachable inner actor (the
    # community's signature is the authentication); every other path
    # requires the actor be present.
    unless actor || via_community
      bad_request("Actor Not Present")
    end

    unless activity && verified
      bad_request("Can't Be Verified")
    end

    # 6

    if actor
      Log.trace { "[#{request_id}] actor iri=#{actor.iri}" }
      actor.up!
      activity.actor = actor
    end

    Log.trace { "[#{request_id}] processing type=#{activity.class}" }

    case activity
    when ActivityPub::Activity::Announce
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      unless object.attributed_to?(account.actor, dereference: true)
        bad_request
      end
    when ActivityPub::Activity::Like, ActivityPub::Activity::Dislike
      # DESIGN DECISION: Actors can both Like AND Dislike the same
      # object. This is intentional - it accurately captures federated
      # state. Some ActivityPub implementations may allow users to both
      # upvote and downvote the same content. Ktistec preserves this
      # state as received.
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      unless object.attributed_to?(account.actor, dereference: true)
        bad_request
      end
      # compatibility with implementations that don't address likes/dislikes
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
      case (object = activity.object?(account.actor, dereference: true, ignore_cached: true))
      when ActivityPub::Actor
        unless object.iri == activity.actor.iri
          bad_request
        end
        object.verify_handle!
        object.up!
        activity.actor = activity.object = object
      when ActivityPub::Object
        unless activity.actor == object.attributed_to?(account.actor, dereference: true)
          bad_request
        end
        object.attributed_to = activity.actor
      else
        bad_request
      end
    when ActivityPub::Activity::Follow
      unless actor
        bad_request
      end
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      # compatibility with implementations that don't address follows
      deliver_to = [account.iri]
    when ActivityPub::Activity::QuoteRequest
      unless (object = activity.object?(account.actor, dereference: true))
        bad_request
      end
      unless object.local? && object.visible
        bad_request
      end
    when ActivityPub::Activity::Accept
      unless activity.object?.try(&.local?)
        bad_request
      end
      unless activity.object.actor == account.actor
        bad_request
      end
      case activity.object
      when ActivityPub::Activity::Follow
        unless Relationship::Social::Follow.find?(actor: account.actor, object: activity.actor)
          bad_request
        end
      when ActivityPub::Activity::QuoteRequest
        # no additional check needed
      else
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
      case activity.object
      when ActivityPub::Activity::Follow
        unless Relationship::Social::Follow.find?(actor: account.actor, object: activity.actor)
          bad_request
        end
      when ActivityPub::Activity::QuoteRequest
        # no additional check needed
      else
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
        unless Relationship::Social::Follow.find?(actor: object.actor, object: object.object)
          bad_request
        end
        deliver_to = [account.iri]
      else
        bad_request
      end
    when ActivityPub::Activity::Delete
      # fetch the object from the database because we can't trust the
      # contents of the payload. also because the original object may
      # be replaced by a tombstone (per the spec).
      if (community = via_community)
        unless (object = ActivityPub::Object.find?(activity.object_iri))
          bad_request
        end
        unless relay_delete_authorized?(account, community, object)
          bad_request
        end
        activity.object = object
        deliver_to = [account.iri]
      else
        unless activity.actor?(account.actor, dereference: true)
          bad_request
        end
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
      end
    else
      bad_request("Activity Not Supported")
    end

    # check to see if the activity already exists. if not, save it

    if (temporary = ActivityPub::Activity.find?(activity.iri))
      activity = temporary
    else
      activity.save
    end

    Log.trace { "[#{request_id}] saved id=#{activity.id}" }

    InboxActivityProcessor.process(account, activity, deliver_to)

    Log.trace { "[#{request_id}] complete" }

    ok
  end

  get "/actors/:username/inbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.account? == account
      forbidden
    end

    activities = account.actor.in_inbox(**cursor_pagination_params(env), public: env.account? != account)

    ok "relationships/inbox", env: env, account: account, activities: activities
  end

  # Activity types that, when wrapped in an `Announce`, indicate a
  # community relay (rather than a share/boost/announce of an object).
  #
  RELAYED_ACTIVITY_TYPES = [
    "https://www.w3.org/ns/activitystreams#Create",
    "https://www.w3.org/ns/activitystreams#Like",
    "https://www.w3.org/ns/activitystreams#Dislike",
    "https://www.w3.org/ns/activitystreams#Update",
    "https://www.w3.org/ns/activitystreams#Undo",
    "https://www.w3.org/ns/activitystreams#Delete",
  ]

  # Detects a community-relayed activity and returns the wrapped inner
  # activity's JSON-LD.
  #
  private def self.relayed_inner_activity(json_ld, request_id)
    type = json_ld.dig?("@type").try(&.as_s)
    return unless type == "https://www.w3.org/ns/activitystreams#Announce"

    object = Ktistec::JSON_LD.dig_first?(json_ld, "https://www.w3.org/ns/activitystreams#object")
    return unless object && object.as_h?

    type = object.dig?("@type").try(&.as_s)
    return unless type && type.in?(RELAYED_ACTIVITY_TYPES)

    Log.debug { "[#{request_id}] relayed #{type.split("#").last} in Announce" }

    object
  rescue ex
    Log.warn { "[#{request_id}] failed to inspect Announce: #{ex.message}" }
    nil
  end
end
