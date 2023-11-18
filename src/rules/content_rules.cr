require "../framework/rule"
# include *every* model to ensure generated
# queries include *all* subtypes.
require "../models/**"
require "../utils/compiler"

# optionally count database operations.

{% if flag?(:"school:metrics") %}
  module DB
    abstract class Statement
      def_around_query_or_exec do |args|
        School::Metrics.count_operation
        yield
      end
    end
  end
{% end %}

class ContentRules
  # patterns and facts for the rules below

  Ktistec::Rule.make_pattern(Actor, ActivityPub::Actor, properties: [:iri, :followers, :following])
  Ktistec::Rule.make_pattern(Activity, ActivityPub::Activity, associations: [:actor])
  Ktistec::Rule.make_pattern(ObjectActivity, ActivityPub::Activity::ObjectActivity, associations: [:actor, :object])
  Ktistec::Rule.make_pattern(Object, ActivityPub::Object, associations: [:in_reply_to, :attributed_to], properties: [:content, :thread])
  Ktistec::Rule.make_pattern(Hashtag, Tag::Hashtag, associations: [subject], properties: [name, href])
  Ktistec::Rule.make_pattern(Mention, Tag::Mention, associations: [subject], properties: [name, href])
  Ktistec::Rule.make_pattern(CreateActivity, ActivityPub::Activity::Create, associations: [:actor, :object])
  Ktistec::Rule.make_pattern(AnnounceActivity, ActivityPub::Activity::Announce, associations: [:actor, :object])
  Ktistec::Rule.make_pattern(LikeActivity, ActivityPub::Activity::Like, associations: [:object])
  Ktistec::Rule.make_pattern(FollowActivity, ActivityPub::Activity::Follow, associations: [:object])
  Ktistec::Rule.make_pattern(DeleteActivity, ActivityPub::Activity::Delete, associations: [:object])
  Ktistec::Rule.make_pattern(UndoActivity, ActivityPub::Activity::Undo, associations: [:object])
  Ktistec::Rule.make_pattern(Outbox, Relationship::Content::Outbox, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(Inbox, Relationship::Content::Inbox, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(Notification, Relationship::Content::Notification, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationLike, Relationship::Content::Notification::Like, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationAnnounce, Relationship::Content::Notification::Announce, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationFollow, Relationship::Content::Notification::Follow, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationHashtag, Relationship::Content::Notification::Hashtag, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationMention, Relationship::Content::Notification::Mention, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationReply, Relationship::Content::Notification::Reply, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationThread, Relationship::Content::Notification::Thread, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(Timeline, Relationship::Content::Timeline, associations: [:owner, :object])
  Ktistec::Rule.make_pattern(TimelineAnnounce, Relationship::Content::Timeline::Announce, associations: [:owner, :object])
  Ktistec::Rule.make_pattern(TimelineCreate, Relationship::Content::Timeline::Create, associations: [:owner, :object])
  Ktistec::Rule.make_pattern(Follow, Relationship::Social::Follow, associations: [:actor, :object])
  Ktistec::Rule.make_pattern(FollowHashtag, Relationship::Content::Follow::Hashtag, associations: [:actor], properties: [:name])
  Ktistec::Rule.make_pattern(FollowMention, Relationship::Content::Follow::Mention, associations: [:actor], properties: [:name])
  Ktistec::Rule.make_pattern(FollowThread, Relationship::Content::Follow::Thread, associations: [:actor], properties: [:thread])
  Ktistec::Rule.make_pattern(Filter, FilterTerm, associations: [:actor], properties: [:term])

  class Outgoing < School::Relationship(ActivityPub::Actor, ActivityPub::Activity) end
  class Incoming < School::Relationship(ActivityPub::Actor, ActivityPub::Activity) end
  class InMailboxOf < School::Relationship(ActivityPub::Activity, ActivityPub::Actor) end
  class IsRecipient < School::Property(String) end

  Ktistec::Compiler.register_constant(ContentRules::Actor)
  Ktistec::Compiler.register_constant(ContentRules::Activity)
  Ktistec::Compiler.register_constant(ContentRules::ObjectActivity)
  Ktistec::Compiler.register_constant(ContentRules::Object)
  Ktistec::Compiler.register_constant(ContentRules::Hashtag)
  Ktistec::Compiler.register_constant(ContentRules::Mention)
  Ktistec::Compiler.register_constant(ContentRules::CreateActivity)
  Ktistec::Compiler.register_constant(ContentRules::AnnounceActivity)
  Ktistec::Compiler.register_constant(ContentRules::LikeActivity)
  Ktistec::Compiler.register_constant(ContentRules::FollowActivity)
  Ktistec::Compiler.register_constant(ContentRules::DeleteActivity)
  Ktistec::Compiler.register_constant(ContentRules::UndoActivity)
  Ktistec::Compiler.register_constant(ContentRules::Outbox)
  Ktistec::Compiler.register_constant(ContentRules::Inbox)
  Ktistec::Compiler.register_constant(ContentRules::Notification)
  Ktistec::Compiler.register_constant(ContentRules::NotificationLike)
  Ktistec::Compiler.register_constant(ContentRules::NotificationAnnounce)
  Ktistec::Compiler.register_constant(ContentRules::NotificationFollow)
  Ktistec::Compiler.register_constant(ContentRules::NotificationHashtag)
  Ktistec::Compiler.register_constant(ContentRules::NotificationMention)
  Ktistec::Compiler.register_constant(ContentRules::NotificationReply)
  Ktistec::Compiler.register_constant(ContentRules::NotificationThread)
  Ktistec::Compiler.register_constant(ContentRules::Timeline)
  Ktistec::Compiler.register_constant(ContentRules::TimelineAnnounce)
  Ktistec::Compiler.register_constant(ContentRules::TimelineCreate)
  Ktistec::Compiler.register_constant(ContentRules::Follow)
  Ktistec::Compiler.register_constant(ContentRules::FollowHashtag)
  Ktistec::Compiler.register_constant(ContentRules::FollowThread)
  Ktistec::Compiler.register_constant(ContentRules::FollowMention)
  Ktistec::Compiler.register_constant(ContentRules::Filter)
  Ktistec::Compiler.register_constant(ContentRules::Incoming)
  Ktistec::Compiler.register_constant(ContentRules::Outgoing)
  Ktistec::Compiler.register_constant(ContentRules::InMailboxOf)
  Ktistec::Compiler.register_constant(ContentRules::IsRecipient)

  Ktistec::Compiler.register_accessor(iri)
  Ktistec::Compiler.register_accessor(content)
  Ktistec::Compiler.register_accessor(following)
  Ktistec::Compiler.register_accessor(followers)

  # Exceptions

  # note: given the way rules are currently evaluated (for a rule,
  # first find all matches, then perform all actions), a condition
  # like `none Notification, owner: actor, activity: activity` will
  # *not* prevent a subsequent assert from attempting to create more
  # than one notification, assuming more than one match. the following
  # adds a check inside `assert` and `retract` for two special cases.

  class NotificationHashtag
    def self.assert(target : School::DomainTypes?, **options : School::DomainTypes)
      unless ::Relationship::Content::Notification::Hashtag.find?(**options)
        ::Relationship::Content::Notification::Hashtag.new(**options).save
      end
    end

    def self.assert(target : School::DomainTypes?, options : Hash(String, School::DomainTypes))
      unless ::Relationship::Content::Notification::Hashtag.find?(options)
        ::Relationship::Content::Notification::Hashtag.new(options).save
      end
    end

    def self.retract(target : School::DomainTypes?, **options : School::DomainTypes)
      if (instance = ::Relationship::Content::Notification::Hashtag.find?(**options))
        instance.destroy
      end
    end

    def self.retract(target : School::DomainTypes?, options : Hash(String, School::DomainTypes))
      if (instance = ::Relationship::Content::Notification::Hashtag.find?(options))
        instance.destroy
      end
    end
  end

  class NotificationMention
    def self.assert(target : School::DomainTypes?, **options : School::DomainTypes)
      unless ::Relationship::Content::Notification::Mention.find?(**options)
        ::Relationship::Content::Notification::Mention.new(**options).save
      end
    end

    def self.assert(target : School::DomainTypes?, options : Hash(String, School::DomainTypes))
      unless ::Relationship::Content::Notification::Mention.find?(options)
        ::Relationship::Content::Notification::Mention.new(options).save
      end
    end

    def self.retract(target : School::DomainTypes?, **options : School::DomainTypes)
      if (instance = ::Relationship::Content::Notification::Mention.find?(**options))
        instance.destroy
      end
    end

    def self.retract(target : School::DomainTypes?, options : Hash(String, School::DomainTypes))
      if (instance = ::Relationship::Content::Notification::Mention.find?(options))
        instance.destroy
      end
    end
  end

  class_property domain : School::Domain do
    definition = File.read(File.join(Dir.current, "etc", "rules", "content.rules"))
    compiler = Ktistec::Compiler.new(definition)
    compiler.compile
  end

  def run
    self.class.domain.run
  end
end
