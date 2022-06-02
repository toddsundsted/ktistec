abstract class Factory
  macro build(type, **options)
    {{type.id}}_factory({{**options}})
  end

  macro create(type, **options)
    {{type.id}}_factory({{**options}}).save
  end
end

KTISTEC_EPOCH = Time.utc(2016, 2, 15, 10, 20, 0)

KTISTEC_FACTORY_STATE = {:nonce => 0, :moment => 0}

macro let_build(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let({{(named || type).id}}) { Factory.build({{type}}, created_at: {{created_at}}, {{**options}}) }
end

macro let_build!(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let!({{(named || type).id}}) { Factory.build({{type}}, created_at: {{created_at}}, {{**options}}) }
end

macro let_create(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let({{(named || type).id}}) { Factory.create({{type}}, created_at: {{created_at}}, {{**options}}) }
end

macro let_create!(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let!({{(named || type).id}}) { Factory.create({{type}}, created_at: {{created_at}}, {{**options}}) }
end

def base_url(iri, thing, local = nil)
  url =
    if local == true
      "https://test.test"
    elsif local == false
      "https://remote"
    elsif iri
      iri
    elsif thing && thing.responds_to?(:iri) && thing.iri
      thing.iri
    else
      "https://remote"
    end
  uri = URI.parse(url.as(String))
  "#{uri.scheme}://#{uri.host}"
end

# actor factories

def actor_factory(clazz = ActivityPub::Actor, with_keys = false, local = nil, **options)
  username = random_string
  iri = local ? "https://test.test/actors/#{username}" : "https://remote/actors/#{username}"
  pem_public_key, pem_private_key =
    if with_keys
      keypair = OpenSSL::RSA.generate(2048, 17)
      {keypair.public_key.to_pem, keypair.to_pem}
    else
      {nil, nil}
    end
  clazz.new(
    **{
      iri: iri,
      inbox: "#{iri}/inbox",
      followers: "#{iri}/followers",
      following: "#{iri}/following",
      pem_public_key: pem_public_key,
      pem_private_key: pem_private_key
    }.merge(options)
  )
end

# object factories

def object_factory(clazz = ActivityPub::Object, iri = nil, attributed_to_iri = nil, attributed_to = false, visible = true, local = nil, **options)
  attributed_to = actor_factory(local: local) unless attributed_to_iri || attributed_to.nil? || attributed_to
  iri ||= "#{base_url(attributed_to_iri, attributed_to, local)}/objects/#{random_string}"
  clazz.new(
    **{
      iri: iri,
      attributed_to_iri: attributed_to_iri,
      attributed_to: attributed_to,
      visible: visible
    }.merge(options)
  )
end

def note_factory(**options)
  object_factory(ActivityPub::Object::Note, **options)
end

def tombstone_factory(**options)
  object_factory(ActivityPub::Object::Tombstone, **options)
end

def video_factory(**options)
  object_factory(ActivityPub::Object::Video, **options)
end

# activity factories

def activity_factory(clazz = ActivityPub::Activity, iri = nil, actor_iri = nil, actor = false, object_iri = nil, object = false, target_iri = nil, target = false, local = nil, **options)
  iri ||= "#{base_url(actor_iri, actor, local)}/activities/#{random_string}"
  actor_iri ||= actor.iri if actor.responds_to?(:iri)
  object_iri ||= object.iri if object.responds_to?(:iri)
  target_iri ||= target.iri if target.responds_to?(:iri)
  clazz.new(
    **{
      iri: iri,
      actor_iri: actor_iri,
      actor: actor,
      object_iri: object_iri,
      object: object,
      target_iri: target_iri,
      target: target,
    }.merge(options)
  )
end

def announce_factory(actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = object_factory(attributed_to_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, attributed_to: actor) unless object_iri || object.nil? || object
  activity_factory(ActivityPub::Activity::Announce, **{actor_iri: actor_iri, actor: actor, object_iri: object_iri, object: object}.merge(options))
end

def like_factory(actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = object_factory(attributed_to_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, attributed_to: actor) unless object_iri || object.nil? || object
  activity_factory(ActivityPub::Activity::Like, **{actor_iri: actor_iri, actor: actor, object_iri: object_iri, object: object}.merge(options))
end

def create_factory(actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = object_factory(attributed_to_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, attributed_to: actor) unless object_iri || object.nil? || object
  activity_factory(ActivityPub::Activity::Create, **{actor_iri: actor_iri, actor: actor, object_iri: object_iri, object: object}.merge(options))
end

def update_factory(actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = object_factory(attributed_to_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, attributed_to: actor) unless object_iri || object.nil? || object
  activity_factory(ActivityPub::Activity::Update, **{actor_iri: actor_iri, actor: actor, object_iri: object_iri, object: object}.merge(options))
end

def undo_factory(actor_iri = nil, actor = false, activity_iri = nil, activity = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  activity = activity_factory(actor_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, actor: actor) unless activity_iri || activity.nil? || activity
  activity_factory(ActivityPub::Activity::Undo, **{actor_iri: actor_iri, actor: actor, object_iri: activity_iri, object: activity}.merge(options))
end

def delete_factory(actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = object_factory(attributed_to_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, attributed_to: actor) unless object_iri || object.nil? || object
  activity_factory(ActivityPub::Activity::Delete, **{actor_iri: actor_iri, actor: actor, object_iri: object_iri, object: object}.merge(options))
end

def follow_factory(**options)
  activity_factory(ActivityPub::Activity::Follow, **options)
end

def accept_factory(**options)
  activity_factory(ActivityPub::Activity::Accept, **options)
end

def reject_factory(**options)
  activity_factory(ActivityPub::Activity::Reject, **options)
end

# collection factories

def collection_factory(clazz = ActivityPub::Collection, **options)
  clazz.new(
    **{iri: "https://remote/collections/#{random_string}"}.merge(options)
  )
end

# relationship factories

def relationship_factory(clazz = Relationship, from_iri = "https://from/#{random_string}", to_iri = "https://to/#{random_string}", **options)
  clazz.new(**{from_iri: from_iri, to_iri: to_iri}.merge(options))
end

def notification_factory(owner_iri = nil, owner = false, activity_iri = nil, activity = false, **options)
  owner = actor_factory unless owner_iri || owner.nil? || owner
  activity = activity_factory(actor_iri: owner_iri || owner.responds_to?(:iri) && owner.iri, actor: owner) unless activity_iri || activity.nil? || activity
  relationship_factory(Relationship::Content::Notification, **{from_iri: owner_iri, owner: owner, to_iri: activity_iri, activity: activity}.merge(options))
end

def timeline_factory(owner_iri = nil, owner = false, object_iri = nil, object = false, **options)
  owner = actor_factory unless owner_iri || owner.nil? || owner
  object = object_factory(attributed_to_iri: owner_iri || owner.responds_to?(:iri) && owner.iri, attributed_to: owner) unless object_iri || object.nil? || object
  relationship_factory(Relationship::Content::Timeline, **{from_iri: owner_iri, owner: owner, to_iri: object_iri, object: object}.merge(options))
end

def inbox_relationship_factory(owner_iri = nil, owner = false, activity_iri = nil, activity = false, **options)
  owner = actor_factory unless owner_iri || owner.nil? || owner
  activity = activity_factory(actor_iri: owner_iri || owner.responds_to?(:iri) && owner.iri, actor: owner) unless activity_iri || activity.nil? || activity
  relationship_factory(Relationship::Content::Inbox, **{from_iri: owner_iri, owner: owner, to_iri: activity_iri, activity: activity}.merge(options))
end

def outbox_relationship_factory(owner_iri = nil, owner = false, activity_iri = nil, activity = false, **options)
  owner = actor_factory unless owner_iri || owner.nil? || owner
  activity = activity_factory(actor_iri: owner_iri || owner.responds_to?(:iri) && owner.iri, actor: owner) unless activity_iri || activity.nil? || activity
  relationship_factory(Relationship::Content::Outbox, **{from_iri: owner_iri, owner: owner, to_iri: activity_iri, activity: activity}.merge(options))
end

def follow_relationship_factory(confirmed = true, **options)
  relationship_factory(Relationship::Social::Follow, **{confirmed: confirmed}.merge(options))
end

def approved_relationship_factory(**options)
  relationship_factory(Relationship::Content::Approved, **options)
end

def canonical_relationship_factory(**options)
  relationship_factory(Relationship::Content::Canonical, **options)
end

# tag factories

def tag_factory(clazz = Tag, **options)
  clazz.new(**options)
end

def hashtag_factory(**options)
  tag_factory(Tag::Hashtag, **options)
end

def mention_factory(**options)
  tag_factory(Tag::Mention, **options)
end

# point factory

def point_factory(clazz = Point, **options)
  clazz.new(**options)
end

# account factory

require "../../src/models/account"

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

def account_factory(clazz = Account, actor_iri = nil, actor = false, username = random_username, password = random_password, **options)
  actor = actor_factory(username: username, local: true) unless actor_iri || actor.nil? || actor
  clazz.new(**{actor_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, actor: actor, username: username, password: password}.merge(options))
end

# other helpers

def put_in_inbox(owner : ActivityPub::Actor, activity : ActivityPub::Activity)
  Factory.create(:inbox_relationship, owner: owner, activity: activity)
end

def put_in_inbox(owner : ActivityPub::Actor, object : ActivityPub::Object)
  activity = Factory.build(:activity, actor: object.attributed_to, object: object)
  Factory.create(:inbox_relationship, owner: owner, activity: activity)
end

def put_in_outbox(owner : ActivityPub::Actor, activity : ActivityPub::Activity)
  Factory.create(:outbox_relationship, owner: owner, activity: activity)
end

def put_in_outbox(owner : ActivityPub::Actor, object : ActivityPub::Object)
  activity = Factory.build(:activity, actor: object.attributed_to, object: object)
  Factory.create(:outbox_relationship, owner: owner, activity: activity)
end

def put_in_notifications(owner : ActivityPub::Actor, activity : ActivityPub::Activity)
  Factory.create(:notification, owner: owner, activity: activity)
end

def put_in_timeline(owner : ActivityPub::Actor, object : ActivityPub::Object)
  Factory.create(:timeline, owner: owner, object: object)
end

def do_follow(actor : ActivityPub::Actor, object : ActivityPub::Actor)
  Factory.create(:follow_relationship, actor: actor, object: object)
end

def register(username = random_username, password = random_password)
  Factory.create(:account, username: username, password: password)
end
