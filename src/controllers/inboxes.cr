require "../framework/ext/openssl"
require "../framework/controller"
require "../framework/json_ld"
require "../utils/network"
require "../framework/signature"
require "../framework/util"
require "../ktistec/constants"
require "../models/activity_pub/activity/**" # ameba:disable Ktistec/NoRequireGlob
require "../services/inbox_activity_processor"

class InboxesController
  include Ktistec::Controller

  Log = ::Log.for("inbox")

  MAX_INBOX_REQUEST_BYTES = 1_048_576

  # Maximum time to spend fetching resources.
  #
  # Verification and dispatch make several sequential fetches --
  # signer key, signer, actor, the activity, its object, its
  # attributed-to.
  #
  # Every figure below is from an analysis of the access log covering
  # 2026-05-26 to 2026-08-04 -- 403,672 inbox POSTs, 95,144 of them
  # 200s -- run on 2026-08-07.
  #
  # 4s is nowhere near the common case: 63.5% of deliveries never
  # fetch at all (medians 0.1-1.0ms), and of all deliveries that
  # succeed, 96.8% finish in under a second. Only a delivery that
  # makes outbound fetches can reach 4s at all.
  #
  # Below 4s is real work: a fetch against a peer has a p75 of 462ms,
  # and the chain of sequential fetches fills the 1-2s band for 2.25%
  # of successful deliveries.
  #
  # Above 4s are our own timeouts: per-operation timeouts are 5s, and
  # the histogram steps across 5s (36 requests in 4.5-5s, 372 in
  # 5-5.5s, ...).
  #
  # Between 2.5s and 5s there is almost nothing -- 0.44% of successful
  # deliveries, spread evenly rather than clustered -- so the cutoff
  # can sit anywhere in that range without splitting a class of
  # deliveries that belong together.
  #
  # The worst case observed is 45.7s. A 4s budget costs ~0.37% of
  # successful deliveries (~5/day), which become 502s and are retried.
  #
  class_property max_inbox_fetch_time : Time::Span = 4.seconds

  skip_auth ["/inbox", "/actors/:username/inbox"], POST

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
  private def self.resolve_signer(key_pair, key_id : String, request_id, transient, deadline)
    if key_id.includes?("#")
      # case 1: fragment URI
      {key_id.split("#", 2).first, nil}
    else
      # cases 2 & 3: path URI
      accept = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
      response = try_dereference(transient, request_id) do
        Ktistec::Network.get(key_pair, key_id, accept, deadline: deadline)
      end
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

  # Records whether a dereference failed for a reason that may not
  # reproduce on redelivery.
  #
  private class Transient
    property? failure = false
  end

  # Dereferences the given IRI, noting whether failure was transient.
  #
  private def self.try_dereference(transient, request_id, &)
    yield
  rescue ex : Ktistec::JSON_LD::MismatchedIRI
    Log.warn { "[#{request_id}] dereference failed (mismatched IRI): #{ex.message}" }
    nil
  rescue ex : Ktistec::Network::DeadlineExceeded
    Log.debug { "[#{request_id}] dereference failed (deadline exceeded): #{ex.message}" }
    transient.failure = true
    nil
  rescue ex : Ktistec::Network::TransientError
    Log.trace { "[#{request_id}] dereference failed (transient): #{ex.message}" }
    transient.failure = true
    nil
  rescue ex : Ktistec::Network::PermanentError | Ktistec::Model::NotFound | Ktistec::JSON_LD::Error | JSON::ParseException | TypeCastError | NotImplementedError
    Log.trace { "[#{request_id}] dereference failed (permanent): #{ex.message}" }
    nil
  end

  # Rejects a delivery with a reason.
  #
  # Both macros read `request_id` and `activity` at the call site.
  #
  # Use `reject` when the delivery is permanently bad. Use
  # `bad_request_or_bad_gateway` -- which additionally reads
  # `transient` -- when an earlier fetch may have failed transiently.
  #
  private macro reject(message)
    Log.debug { "[#{request_id}] rejected #{activity.class}: #{ {{message}} }" }
    bad_request({{message}})
  end

  # :ditto:
  private macro bad_request_or_bad_gateway(message)
    if transient.failure?
      Log.debug { "[#{request_id}] rejected #{activity.class}: #{ {{message}} } (transient)" }
      bad_gateway({{message}})
    else
      Log.debug { "[#{request_id}] rejected #{activity.class}: #{ {{message}} }" }
      bad_request({{message}})
    end
  end

  # Finds a cached actor by IRI, or dereferences and saves it.
  #
  private def self.find_or_dereference_actor(key_pair, iri, request_id, transient, deadline, require_key)
    return unless iri
    actor = ActivityPub::Actor.find?(iri)
    return actor if actor && (!require_key || actor.pem_public_key)
    try_dereference(transient, request_id) do
      ActivityPub::Actor.dereference(key_pair, iri, ignore_cached: true, include_key: true, deadline: deadline)
    end.try do |dereferenced|
      dereferenced.verify_handle!(deadline)
      dereferenced.save
    end
  end

  # Authorizes a community-relayed `Delete`.
  #
  private def self.relay_delete_authorized?(key_pair, community, object, transient, deadline)
    if (audience = object.audience) && audience.includes?(community.iri) &&
       Account.all.any? { |local| Relationship::Social::Follow.find?(actor: local.actor, object: community) }
      return true
    end
    object_gone_at_origin?(key_pair, object.iri, transient, deadline)
  end

  # Authorizes an `Accept` or `Reject` of a `QuoteRequest`.
  #
  private def self.answer_quote_request_authorized?(activity)
    return false unless (quote_request = activity.object?.as?(ActivityPub::Activity::QuoteRequest))
    return false unless (quoted_object = quote_request.object?)
    return false unless (actor_iri = activity.actor_iri)
    actor_iri == quoted_object.attributed_to_iri
  end

  # Returns true if the object is gone (404/410) at its own origin.
  #
  private def self.object_gone_at_origin?(key_pair, iri, transient, deadline)
    headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
    Ktistec::Network.get(key_pair, iri, headers, deadline: deadline)
    false
  rescue Ktistec::Network::TransientError
    transient.failure = true
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

  post "/inbox", "/actors/:username/inbox" do |env|
    request_id = env.request.object_id

    if Ktistec::Server.shutting_down?
      service_unavailable
    end

    account = get_account(env)

    if env.params.url["username"]? && account.nil?
      gone
    end

    # the identity that signs the requests made while verifying and
    # dereferencing this activity. the account named in the path when
    # there is one, otherwise an arbitrary local account.

    unless (fetch_identity = account.try(&.actor) || Account.all.first?.try(&.actor))
      service_unavailable
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
    # should be idempotent, but it avoids a lot of unnecessary work.

    if Relationship::Content::Inbox.count(activity: activity) > 0
      ok
    end

    # a directly-delivered `Delete` for an uncached object or actor is
    # a no-op -- there is nothing to delete. nevertheless, processing
    # those deletes runs multiple doomed fetches -- each bounded only
    # by the network timeout -- and deletes arrive in storms. this
    # fast-path addresses that.

    if !inner_ld &&
       activity.is_a?(ActivityPub::Activity::Delete) &&
       (object_iri = activity.object_iri) &&
       ActivityPub::Object.find?(object_iri).nil? &&
       ActivityPub::Actor.find?(object_iri).nil?
      Log.trace { "[#{request_id}] delete of unknown target iri=#{object_iri}; accepting without verification" }
      ok
    end

    # 1) resolve the keyId from the Signature header to the signer and
    # its verification key. 2) verify the signature against the raw
    # body. 3a) a relayed Delete is authenticated by the relaying
    # community's (Group) Announce signature. 3b) a directly-delivered
    # activity is authenticated when the signer is its own actor.
    # otherwise, verify the activity by 4) returning it from the
    # database if we already hold it, and retrieving it from its
    # origin if we do not, or 5) as a last resort, checking the
    # existence of its object or actor. finally, 6) associate the
    # verified activity with its actor.

    # important: never use/trust credentials in an embedded actor!

    # 1 & 2

    signer = nil

    transient = Transient.new

    deadline = Time.instant + max_inbox_fetch_time

    if (key_id = parse_key_id(env.request.headers)) && (resolved = resolve_signer(fetch_identity, key_id, request_id, transient, deadline))
      signer_iri, resolved_key = resolved
      candidate = find_or_dereference_actor(fetch_identity, signer_iri, request_id, transient, deadline, require_key: resolved_key.nil?)
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
      actor = find_or_dereference_actor(fetch_identity, activity.actor_iri, request_id, transient, deadline, require_key: false)
    elsif !inner_ld && signer && outer_actor_iri && signer.iri == outer_actor_iri
      actor = signer
      verified = true
    else
      actor = find_or_dereference_actor(fetch_identity, activity.actor_iri, request_id, transient, deadline, require_key: false)

      # 4

      temporary =
        if activity.iri.presence
          try_dereference(transient, request_id) do
            ActivityPub::Activity.dereference(fetch_identity, activity.iri, deadline: deadline)
          end
        end

      if temporary
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
            temporary = try_dereference(transient, request_id) do
              ActivityPub::Object.dereference(fetch_identity, object_iri, ignore_cached: true, deadline: deadline)
            end
            if temporary
              activity.object = temporary
              verified = true
            end
          elsif activity.is_a?(ActivityPub::Activity::Update)
            Log.trace { "[#{request_id}] checking object of update iri=#{object_iri}" }
            temporary = try_dereference(transient, request_id) do
              ActivityPub::Object.dereference(fetch_identity, object_iri, ignore_cached: true, deadline: deadline)
            end
            if temporary
              activity.object = temporary
              verified = true
            end
          elsif activity.is_a?(ActivityPub::Activity::Delete)
            Log.trace { "[#{request_id}] checking object of delete iri=#{object_iri}" }
            verified = true if object_gone_at_origin?(fetch_identity, object_iri, transient, deadline)
          end
        end
      end
    end

    # the relayed-Delete path tolerates an unreachable inner actor (the
    # community's signature is the authentication); every other path
    # requires the actor be present.
    unless actor || via_community
      bad_request_or_bad_gateway("Actor Not Present")
    end

    unless activity && verified
      bad_request_or_bad_gateway("Can't Be Verified")
    end

    # an activity's own identifier must have the same origin as its
    # actor. this holds for a relayed activity too, where the inner
    # activity's `@id` and actor both belong to the original author
    # rather than to the relaying community.
    if (activity_iri = activity.iri.presence) && (activity_actor_iri = activity.actor_iri)
      unless Ktistec::Util.same_origin?(activity_iri, activity_actor_iri)
        Log.trace { "[#{request_id}] activity iri=#{activity_iri} is not on the actor's origin actor=#{activity_actor_iri}" }
        reject("Origin Mismatch")
      end
    end

    # 6

    if actor
      Log.trace { "[#{request_id}] actor iri=#{actor.iri}" }
      actor.up!
      activity.actor = actor
    end

    recipients = Ktistec::Recipients.local_recipients(activity)
    deliver_to = recipients.map(&.iri)

    Log.trace { "[#{request_id}] processing type=#{activity.class} recipients=#{deliver_to}" }

    # a verified activity's earlier failures must not turn a permanent rejection into a 502
    transient = Transient.new

    case activity
    when ActivityPub::Activity::Announce
      unless (object = try_dereference(transient, request_id) { activity.object(fetch_identity, dereference: true, deadline: deadline) })
        bad_request_or_bad_gateway("Object Not Present")
      end
      unless try_dereference(transient, request_id) { object.attributed_to(fetch_identity, dereference: true, deadline: deadline) }
        bad_request_or_bad_gateway("Object Attribution Not Present")
      end
    when ActivityPub::Activity::Like, ActivityPub::Activity::Dislike
      unless (object = try_dereference(transient, request_id) { activity.object(fetch_identity, dereference: true, deadline: deadline) })
        bad_request_or_bad_gateway("Object Not Present")
      end
      unless try_dereference(transient, request_id) { object.attributed_to(fetch_identity, dereference: true, deadline: deadline) }
        bad_request_or_bad_gateway("Object Attribution Not Present")
      end
    when ActivityPub::Activity::Create
      unless (object = try_dereference(transient, request_id) { activity.object(fetch_identity, dereference: true, ignore_cached: true, deadline: deadline) })
        bad_request_or_bad_gateway("Object Not Present")
      end
      unless activity.actor == try_dereference(transient, request_id) { object.attributed_to(fetch_identity, dereference: true, deadline: deadline) }
        bad_request_or_bad_gateway("Object Not Attributed To Actor")
      end
      object.attributed_to = activity.actor
    when ActivityPub::Activity::Update
      case (object = try_dereference(transient, request_id) { activity.object(fetch_identity, dereference: true, ignore_cached: true, deadline: deadline) })
      when ActivityPub::Actor
        unless object.iri == activity.actor.iri
          reject("Actor Mismatch")
        end
        object.verify_handle!(deadline)
        object.up!
        activity.actor = activity.object = object
      when ActivityPub::Object
        unless activity.actor == try_dereference(transient, request_id) { object.attributed_to(fetch_identity, dereference: true, deadline: deadline) }
          bad_request_or_bad_gateway("Object Not Attributed To Actor")
        end
        object.attributed_to = activity.actor
      else
        bad_request_or_bad_gateway("Object Not Present")
      end
    when ActivityPub::Activity::Follow
      unless actor
        reject("Actor Not Present")
      end
      unless (object = try_dereference(transient, request_id) { activity.object(fetch_identity, dereference: true, deadline: deadline) })
        bad_request_or_bad_gateway("Object Not Present")
      end
    when ActivityPub::Activity::QuoteRequest
      unless (object = try_dereference(transient, request_id) { activity.object(fetch_identity, dereference: true, deadline: deadline) })
        bad_request_or_bad_gateway("Object Not Present")
      end
      unless object.local? && object.visible
        reject("Object Not Quotable")
      end
    when ActivityPub::Activity::Accept
      unless activity.object?.try(&.local?)
        reject("Object Not Local")
      end
      unless recipients.any? { |recipient| recipient.iri == activity.object.actor.iri }
        reject("Object Actor Not A Recipient")
      end
      case activity.object
      when ActivityPub::Activity::Follow
        unless Relationship::Social::Follow.find?(actor: activity.object.actor, object: activity.actor)
          reject("Follow Not Present")
        end
      when ActivityPub::Activity::QuoteRequest
        unless answer_quote_request_authorized?(activity)
          reject("Quote Request Not Authorized")
        end
      else
        reject("Object Type Not Supported")
      end
    when ActivityPub::Activity::Reject
      unless activity.object?.try(&.local?)
        reject("Object Not Local")
      end
      unless recipients.any? { |recipient| recipient.iri == activity.object.actor.iri }
        reject("Object Actor Not A Recipient")
      end
      case activity.object
      when ActivityPub::Activity::Follow
        unless Relationship::Social::Follow.find?(actor: activity.object.actor, object: activity.actor)
          reject("Follow Not Present")
        end
      when ActivityPub::Activity::QuoteRequest
        unless answer_quote_request_authorized?(activity)
          reject("Quote Request Not Authorized")
        end
      else
        reject("Object Type Not Supported")
      end
    when ActivityPub::Activity::Undo
      unless activity.actor?(fetch_identity, dereference: true, deadline: deadline)
        reject("Actor Not Present")
      end
      # an undo names a prior activity (as its `object`). if there is
      # no database record, there is nothing to undo.
      unless (object = ActivityPub::Activity.find?(activity.object_iri, include_undone: true))
        reject("Object Not Present")
      end
      activity.object = object
      case object
      when ActivityPub::Activity::Announce, ActivityPub::Activity::Like, ActivityPub::Activity::Dislike
        unless object.actor_iri == activity.actor_iri
          reject("Actor Mismatch")
        end
      when ActivityPub::Activity::Follow
        unless (followed = object.object?(include_deleted: true)) && followed.local?
          reject("Follow Object Not Local")
        end
        unless object.actor_iri == activity.actor_iri
          reject("Actor Mismatch")
        end
        unless object.undone? || Relationship::Social::Follow.find?(actor: activity.actor, object: followed)
          reject("Follow Not Present")
        end
      else
        reject("Object Type Not Supported")
      end
    when ActivityPub::Activity::Delete
      # fetch the object from the database because we can't trust the
      # contents of the payload. also because the original object may
      # be replaced by a tombstone (per the spec).
      if (community = via_community)
        unless (object = ActivityPub::Object.find?(activity.object_iri, include_deleted: true))
          reject("Object Not Present")
        end
        unless relay_delete_authorized?(fetch_identity, community, object, transient, deadline)
          bad_request_or_bad_gateway("Relay Delete Not Authorized")
        end
        activity.object = object
      else
        unless activity.actor?(fetch_identity, dereference: true, deadline: deadline)
          reject("Actor Not Present")
        end
        if (object = ActivityPub::Object.find?(activity.object_iri))
          unless object.attributed_to? == activity.actor
            reject("Object Not Attributed To Actor")
          end
          activity.object = object
        elsif (object = ActivityPub::Actor.find?(activity.object_iri))
          unless object == activity.actor
            reject("Actor Mismatch")
          end
          activity.actor = activity.object = object
        else
          reject("Object Not Present")
        end
      end
    else
      reject("Activity Not Supported")
    end

    unless activity.is_a?(ActivityPub::Activity::Delete)
      if activity.responds_to?(:object?) && activity.object?.is_a?(ActivityPub::Object::QuoteAuthorization)
        reject("Quote Authorization Not Allowed")
      end
    end

    # check to see if the activity already exists. if not, save it

    if (temporary = ActivityPub::Activity.find?(activity.iri))
      activity = temporary
    else
      begin
        activity.save
      rescue ex : Ktistec::Model::Invalid
        # a concurrent duplicate delivery can save this activity (or its
        # cascade-saved object) between the check above and this save,
        # tripping a uniqueness validation.
        raise ex unless ActivityPub::Activity.find?(activity.iri)
        ok
      end
    end

    Log.trace { "[#{request_id}] saved id=#{activity.id}" }

    InboxActivityProcessor.process(account, activity, deliver_to, recipients: recipients, deadline: deadline)

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
