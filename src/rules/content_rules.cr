require "school/domain/builder"

require "../utils/compiler"
require "../framework/rule"
require "../models/activity_pub/activity"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"

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
  # domain types

  class ::ActivityPub::Activity include School::DomainType end
  class ::ActivityPub::Actor include School::DomainType end
  class ::ActivityPub::Object include School::DomainType end
  class ::Relationship::Content::Notification include School::DomainType end
  class ::Relationship::Content::Timeline include School::DomainType end
  class ::Tag::Mention include School::DomainType end

  # patterns and facts for the rules below

  Ktistec::Rule.make_pattern(Object, ActivityPub::Object, associations: [:in_reply_to, :attributed_to])
  Ktistec::Rule.make_pattern(Mention, Tag::Mention, associations: [subject], properties: [href])
  Ktistec::Rule.make_pattern(CreateActivity, ActivityPub::Activity::Create, associations: [:object])
  Ktistec::Rule.make_pattern(AnnounceActivity, ActivityPub::Activity::Announce, associations: [:object])
  Ktistec::Rule.make_pattern(LikeActivity, ActivityPub::Activity::Like, associations: [:object])
  Ktistec::Rule.make_pattern(FollowActivity, ActivityPub::Activity::Follow, associations: [:object])
  Ktistec::Rule.make_pattern(DeleteActivity, ActivityPub::Activity::Delete, associations: [:object])
  Ktistec::Rule.make_pattern(UndoActivity, ActivityPub::Activity::Undo, associations: [:object])
  Ktistec::Rule.make_pattern(Notification, Relationship::Content::Notification, associations: [:owner, :activity])
  Ktistec::Rule.make_pattern(Timeline, Relationship::Content::Timeline, associations: [:owner, :object])

  class IsAddressedTo < School::Relationship(ActivityPub::Activity, ActivityPub::Actor) end

  Ktistec::Compiler.register_constant(ContentRules::Object)
  Ktistec::Compiler.register_constant(ContentRules::Mention)
  Ktistec::Compiler.register_constant(ContentRules::CreateActivity)
  Ktistec::Compiler.register_constant(ContentRules::AnnounceActivity)
  Ktistec::Compiler.register_constant(ContentRules::LikeActivity)
  Ktistec::Compiler.register_constant(ContentRules::FollowActivity)
  Ktistec::Compiler.register_constant(ContentRules::DeleteActivity)
  Ktistec::Compiler.register_constant(ContentRules::UndoActivity)
  Ktistec::Compiler.register_constant(ContentRules::Notification)
  Ktistec::Compiler.register_constant(ContentRules::Timeline)
  Ktistec::Compiler.register_constant(ContentRules::IsAddressedTo)
  Ktistec::Compiler.register_accessor(iri)

  protected class_property domain : School::Domain do
    definition = <<-RULE
      # Notifications

      rule "create"
        condition activity, IsAddressedTo, actor
        condition CreateActivity, activity, object: object
        any Mention, mention, subject: object, href: actor.iri
        none Notification, owner: actor, activity: activity
        assert Notification, owner: actor, activity: activity
      end

      rule "announce"
        condition activity, IsAddressedTo, actor
        condition AnnounceActivity, activity, object: object1
        condition Object, object1, attributed_to: actor
        none Notification, owner: actor, activity: activity
        assert Notification, owner: actor, activity: activity
      end

      rule "like"
        condition activity, IsAddressedTo, actor
        condition LikeActivity, activity, object: object2
        condition Object, object2, attributed_to: actor
        none Notification, owner: actor, activity: activity
        assert Notification, owner: actor, activity: activity
      end

      rule "follow"
        condition activity, IsAddressedTo, actor
        condition FollowActivity, activity, object: actor
        none Notification, owner: actor, activity: activity
        assert Notification, owner: actor, activity: activity
      end

      rule "delete"
        condition delete, IsAddressedTo, actor
        condition DeleteActivity, delete, object: object
        condition CreateActivity, activity, object: object
        any Notification, owner: actor, activity: activity
        retract Notification, owner: actor, activity: activity
      end

      rule "undo"
        condition undo, IsAddressedTo, actor
        condition UndoActivity, undo, object: activity
        any Notification, owner: actor, activity: activity
        retract Notification, owner: actor, activity: activity
      end

      # Timeline

      # the first two rules would be one rule if "or" was supported.
      # notify if there are either no replies and no mentions, or the
      # actor is mentioned.

      rule "create"
        condition activity, IsAddressedTo, actor
        condition CreateActivity, activity, object: object
        none Object, object, in_reply_to: any
        none Mention, mention, subject: object
        none Timeline, owner: actor, object: object
        assert Timeline, owner: actor, object: object
      end

      rule "create"
        condition activity, IsAddressedTo, actor
        condition CreateActivity, activity, object: object
        any Mention, mention, subject: object, href: actor.iri
        none Timeline, owner: actor, object: object
        assert Timeline, owner: actor, object: object
      end

      rule "announce"
        condition activity, IsAddressedTo, actor
        condition AnnounceActivity, activity, object: object
        none Timeline, owner: actor, object: object
        assert Timeline, owner: actor, object: object
      end

      rule "delete"
        condition activity, IsAddressedTo, actor
        condition DeleteActivity, activity, object: object
        any Timeline, owner: actor, object: object
        retract Timeline, owner: actor, object: object
      end

      rule "undo"
        condition undo, IsAddressedTo, actor
        condition UndoActivity, undo, object: activity
        condition AnnounceActivity, activity, object: object
        none CreateActivity, object: object
        none AnnounceActivity, not activity, object: object
        any Timeline, owner: actor, object: object
        retract Timeline, owner: actor, object: object
      end
    RULE
    compiler = Ktistec::Compiler.new(definition)
    compiler.compile
  end

  def run(actor, activity)
    School::Fact.clear!

    raise "actor must be local" unless actor.local?

    self.class.domain.assert(IsAddressedTo.new(activity, actor))

    5.times do |i|
      break if self.class.domain.run == School::Domain::Status::Completed
      raise "iteration limit exceeded" if i >= 4
    end
  end
end
