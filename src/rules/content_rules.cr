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
  Ktistec::Rule.make_pattern(Object, ActivityPub::Object, associations: [:in_reply_to, :attributed_to], properties: [:content])
  Ktistec::Rule.make_pattern(Mention, Tag::Mention, associations: [subject], properties: [href])
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
  Ktistec::Rule.make_pattern(NotificationMention, Relationship::Content::Notification::Mention, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(NotificationReply, Relationship::Content::Notification::Reply, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(Timeline, Relationship::Content::Timeline, associations: [:owner, :object])
  Ktistec::Rule.make_pattern(TimelineAnnounce, Relationship::Content::Timeline::Announce, associations: [:owner, :object])
  Ktistec::Rule.make_pattern(TimelineCreate, Relationship::Content::Timeline::Create, associations: [:owner, :object])
  Ktistec::Rule.make_pattern(Follow, Relationship::Social::Follow, associations: [:actor, :object])
  Ktistec::Rule.make_pattern(Filter, FilterTerm, associations: [:actor], properties: [:term])

  class Outgoing < School::Relationship(ActivityPub::Actor, ActivityPub::Activity) end
  class Incoming < School::Relationship(ActivityPub::Actor, ActivityPub::Activity) end
  class IsAddressedTo < School::Relationship(ActivityPub::Activity, ActivityPub::Actor) end
  class IsRecipient < School::Property(String) end

  Ktistec::Compiler.register_constant(ContentRules::Actor)
  Ktistec::Compiler.register_constant(ContentRules::Activity)
  Ktistec::Compiler.register_constant(ContentRules::Object)
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
  Ktistec::Compiler.register_constant(ContentRules::NotificationMention)
  Ktistec::Compiler.register_constant(ContentRules::NotificationReply)
  Ktistec::Compiler.register_constant(ContentRules::Timeline)
  Ktistec::Compiler.register_constant(ContentRules::TimelineAnnounce)
  Ktistec::Compiler.register_constant(ContentRules::TimelineCreate)
  Ktistec::Compiler.register_constant(ContentRules::Follow)
  Ktistec::Compiler.register_constant(ContentRules::Filter)
  Ktistec::Compiler.register_constant(ContentRules::Incoming)
  Ktistec::Compiler.register_constant(ContentRules::Outgoing)
  Ktistec::Compiler.register_constant(ContentRules::IsAddressedTo)
  Ktistec::Compiler.register_constant(ContentRules::IsRecipient)

  Ktistec::Compiler.register_accessor(iri)
  Ktistec::Compiler.register_accessor(content)
  Ktistec::Compiler.register_accessor(following)
  Ktistec::Compiler.register_accessor(followers)

  class_property domain : School::Domain do
    definition = File.read(File.join(Dir.current, "etc", "rules", "content.rules"))
    compiler = Ktistec::Compiler.new(definition)
    compiler.compile
  end

  def run
    self.class.domain.run
  end
end
