abstract class Factory
  macro build(type, **options)
    {{type.id}}_factory({{options.double_splat}})
  end

  macro create(type, **options)
    {{type.id}}_factory({{options.double_splat}}).save
  end
end

KTISTEC_EPOCH = Time.utc(2016, 2, 15, 10, 20, 0)

KTISTEC_FACTORY_STATE = {:nonce => 0, :moment => 0}

macro let_build(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let({{(named || type).id}}) { Factory.build({{type}}, created_at: {{created_at}}, {{options.double_splat}}) }
end

macro let_build!(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let!({{(named || type).id}}) { Factory.build({{type}}, created_at: {{created_at}}, {{options.double_splat}}) }
end

macro let_create(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let({{(named || type).id}}) { Factory.create({{type}}, created_at: {{created_at}}, {{options.double_splat}}) }
end

macro let_create!(type, named = false, created_at = KTISTEC_EPOCH + (KTISTEC_FACTORY_STATE[:moment] += 1).second, **options)
  {% named = "__anon_#{KTISTEC_FACTORY_STATE[:nonce] += 1}" if named == nil %}
  let!({{(named || type).id}}) { Factory.create({{type}}, created_at: {{created_at}}, {{options.double_splat}}) }
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
      keypair = OpenSSL::RSA.generate(512, 17)
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
  clazz.new({
    "iri" => iri,
    "attributed_to_iri" => attributed_to_iri,
    "attributed_to" => attributed_to,
    "visible" => visible
  }.merge(options.to_h.transform_keys(&.to_s)).compact)
end

def note_factory(**options)
  object_factory(ActivityPub::Object::Note, **options)
end

def tombstone_factory(**options)
  object_factory(ActivityPub::Object::Tombstone, **options)
end

# activity factories

def activity_factory(clazz = ActivityPub::Activity, iri = nil, actor_iri = nil, actor = false, object_iri = nil, object = false, target_iri = nil, target = false, local = nil, **options)
  iri ||= "#{base_url(actor_iri, actor, local)}/activities/#{random_string}"
  actor_iri ||= actor.iri if actor.responds_to?(:iri)
  object_iri ||= object.iri if object.responds_to?(:iri)
  target_iri ||= target.iri if target.responds_to?(:iri)
  clazz.new({
    "iri" => iri,
    "actor_iri" => actor_iri,
    "actor" => actor ? actor : nil,
    "object_iri" => object_iri,
    "object" => object ? object : nil,
    "target_iri" => target_iri,
    "target" => target ? target : nil
  }.merge(options.to_h.transform_keys(&.to_s)).compact)
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

def follow_factory(actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = actor_factory unless object_iri || object.nil? || object
  activity_factory(ActivityPub::Activity::Follow, **{actor_iri: actor_iri, actor: actor, object_iri: object_iri, object: object}.merge(options))
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
  clazz.new({"from_iri" => from_iri, "to_iri" => to_iri}.merge(options.to_h.transform_keys(&.to_s)).compact)
end

def notification_factory(clazz = Relationship::Content::Notification, activity_clazz = ActivityPub::Activity, owner_iri = nil, owner = false, activity_iri = nil, activity = false, **options)
  owner = actor_factory unless owner_iri || owner.nil? || owner
  activity = activity_factory(activity_clazz, actor_iri: owner_iri || owner.responds_to?(:iri) && owner.iri, actor: owner) unless activity_iri || activity.nil? || activity
  relationship_factory(clazz, **{from_iri: owner_iri, owner: owner, to_iri: activity_iri, activity: activity}.merge(options))
end

def notification_announce_factory(**options)
  notification_factory(Relationship::Content::Notification::Announce, ActivityPub::Activity::Announce, **options)
end

def notification_like_factory(**options)
  notification_factory(Relationship::Content::Notification::Like, ActivityPub::Activity::Like, **options)
end

def notification_follow_factory(**options)
  notification_factory(Relationship::Content::Notification::Follow, ActivityPub::Activity::Follow, **options)
end

def notification_follow_hashtag_factory(**options)
  notification_factory(Relationship::Content::Notification::Follow::Hashtag, **{activity: nil}.merge(options))
end

def notification_follow_mention_factory(**options)
  notification_factory(Relationship::Content::Notification::Follow::Mention, **{activity: nil}.merge(options))
end

def notification_follow_thread_factory(**options)
  notification_factory(Relationship::Content::Notification::Follow::Thread, **{activity: nil}.merge(options))
end

def notification_reply_factory(**options)
  notification_factory(Relationship::Content::Notification::Reply, **{activity: nil}.merge(options))
end

def notification_mention_factory(**options)
  notification_factory(Relationship::Content::Notification::Mention, **{activity: nil}.merge(options))
end

def timeline_factory(clazz = Relationship::Content::Timeline, owner_iri = nil, owner = false, object_iri = nil, object = false, **options)
  owner = actor_factory unless owner_iri || owner.nil? || owner
  object = object_factory(attributed_to_iri: owner_iri || owner.responds_to?(:iri) && owner.iri, attributed_to: owner) unless object_iri || object.nil? || object
  relationship_factory(clazz, **{from_iri: owner_iri, owner: owner, to_iri: object_iri, object: object}.merge(options))
end

def timeline_announce_factory(**options)
  timeline_factory(Relationship::Content::Timeline::Announce, **options)
end

def timeline_create_factory(**options)
  timeline_factory(Relationship::Content::Timeline::Create, **options)
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

def follow_relationship_factory(confirmed = true, actor_iri = nil, actor = false, object_iri = nil, object = false, **options)
  actor = actor_factory unless actor_iri || actor.nil? || actor
  object = actor_factory unless object_iri || object.nil? || object
  relationship_factory(Relationship::Social::Follow, **{confirmed: confirmed, from_iri: actor_iri, actor: actor, to_iri: object_iri, object: object}.merge(options))
end

def follow_hashtag_relationship_factory(**options)
  relationship_factory(Relationship::Content::Follow::Hashtag, **options)
end

def follow_mention_relationship_factory(**options)
  relationship_factory(Relationship::Content::Follow::Mention, **options)
end

def follow_thread_relationship_factory(**options)
  relationship_factory(Relationship::Content::Follow::Thread, **options)
end

def approved_relationship_factory(**options)
  relationship_factory(Relationship::Content::Approved, **options)
end

def canonical_relationship_factory(**options)
  relationship_factory(Relationship::Content::Canonical, **options)
end

# task factories

def task_factory(clazz = Task, source_iri = "https://source/#{random_string}", subject_iri = "https://subject/#{random_string}", **options)
  clazz.new({"source_iri" => source_iri, "subject_iri" => subject_iri}.merge(options.to_h.transform_keys(&.to_s)).compact)
end

def fetch_hashtag_task_factory(source_iri = nil, source = false, **options)
  source = actor_factory(local: true) unless source_iri || source.nil? || source
  task_factory(Task::Fetch::Hashtag, **{source: source, source_iri: source_iri}.merge(options))
end

def fetch_thread_task_factory(source_iri = nil, source = false, **options)
  source = actor_factory(local: true) unless source_iri || source.nil? || source
  task_factory(Task::Fetch::Thread, **{source: source, source_iri: source_iri}.merge(options))
end

class Factory::ConcurrentTask < Task
  include Task::ConcurrentTask

  def perform
    # no-op
  end
end

def concurrent_task_factory(**options)
  # tests using concurrent tasks depend on tasks being assigned unique ids
  task_factory(Factory::ConcurrentTask, **{id: rand(1_000_000_i64)}.merge(options))
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

# filter term factory

def filter_term_factory(clazz = FilterTerm, actor_id = nil, actor = false, **options)
  actor = actor_factory(local: true) unless actor_id || actor.nil? || actor
  clazz.new(**{actor_id: actor_id, actor: actor}.merge(options))
end

# translation factory

def translation_factory(clazz = Translation, origin_id = nil, origin = false, **options)
  origin = object_factory unless origin_id || origin.nil? || origin
  clazz.new(**{origin_id: origin_id, origin: origin}.merge(options))
end

# account factory

require "../../src/models/account"

class Account
  private def cost
    4 # reduce the cost of computing a bcrypt hash
  end
end

def account_factory(clazz = Account, actor_iri = nil, actor = false, username = random_username, password = random_password, language = "en", **options)
  actor = actor_factory(username: username, local: true) unless actor_iri || actor.nil? || actor
  clazz.new(**{actor_iri: actor_iri || actor.responds_to?(:iri) && actor.iri, actor: actor, username: username, password: password, language: language}.merge(options))
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

def put_in_notifications(owner : ActivityPub::Actor, *, mention : ActivityPub::Activity::Create)
  Factory.create(:notification_mention, owner: owner, object: mention.object)
end

def put_in_notifications(owner : ActivityPub::Actor, *, reply : ActivityPub::Activity::Create)
  Factory.create(:notification_reply, owner: owner, object: reply.object)
end

def put_in_notifications(owner : ActivityPub::Actor, activity : ActivityPub::Activity::Announce)
  Factory.create(:notification_announce, owner: owner, activity: activity)
end

def put_in_notifications(owner : ActivityPub::Actor, activity : ActivityPub::Activity::Like)
  Factory.create(:notification_like, owner: owner, activity: activity)
end

def put_in_notifications(owner : ActivityPub::Actor, activity : ActivityPub::Activity::Follow)
  Factory.create(:notification_follow, owner: owner, activity: activity)
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
