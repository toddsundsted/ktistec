require "school/domain/builder"

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

  private getter domain : School::Domain do
    School.domain do
      # Notifications

      rule "create" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition CreateActivity, var("activity"), object: var("object")
        any Mention, var("mention"), subject: var("object"), href: var("actor").iri
        none Notification, owner: var("actor"), activity: var("activity")
        assert Notification, owner: var("actor"), activity: var("activity")
      end

      rule "announce" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition AnnounceActivity, var("activity"), object: var("object")
        condition Object, var("object"), attributed_to: var("actor")
        none Notification, owner: var("actor"), activity: var("activity")
        assert Notification, owner: var("actor"), activity: var("activity")
      end

      rule "like" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition LikeActivity, var("activity"), object: var("object")
        condition Object, var("object"), attributed_to: var("actor")
        none Notification, owner: var("actor"), activity: var("activity")
        assert Notification, owner: var("actor"), activity: var("activity")
      end

      rule "follow" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition FollowActivity, var("activity"), object: var("actor")
        none Notification, owner: var("actor"), activity: var("activity")
        assert Notification, owner: var("actor"), activity: var("activity")
      end

      rule "delete" do
        condition var("delete"), IsAddressedTo, var("actor")
        condition DeleteActivity, var("delete"), object: var("object")
        condition CreateActivity, var("activity"), object: var("object")
        any Notification, owner: var("actor"), activity: var("activity")
        retract Notification, owner: var("actor"), activity: var("activity")
      end

      rule "undo" do
        condition var("undo"), IsAddressedTo, var("actor")
        condition UndoActivity, var("undo"), object: var("activity")
        any Notification, owner: var("actor"), activity: var("activity")
        retract Notification, owner: var("actor"), activity: var("activity")
      end

      # Timeline

      # the first two rules would be one rule if "or" was supported.
      # notify if there are either no replies and no mentions, or the
      # actor is mentioned.

      rule "create" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition CreateActivity, var("activity"), object: var("object")
        none Object, var("object"), in_reply_to: var("any")
        none Mention, var("mention"), subject: var("object")
        none Timeline, owner: var("actor"), object: var("object")
        assert Timeline, owner: var("actor"), object: var("object")
      end

      rule "create" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition CreateActivity, var("activity"), object: var("object")
        any Mention, var("mention"), subject: var("object"), href: var("actor").iri
        none Timeline, owner: var("actor"), object: var("object")
        assert Timeline, owner: var("actor"), object: var("object")
      end

      rule "announce" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition AnnounceActivity, var("activity"), object: var("object")
        none Timeline, owner: var("actor"), object: var("object")
        assert Timeline, owner: var("actor"), object: var("object")
      end

      rule "delete" do
        condition var("activity"), IsAddressedTo, var("actor")
        condition DeleteActivity, var("activity"), object: var("object")
        any Timeline, owner: var("actor"), object: var("object")
        retract Timeline, owner: var("actor"), object: var("object")
      end

      rule "undo" do
        condition var("undo"), IsAddressedTo, var("actor")
        condition UndoActivity, var("undo"), object: var("activity")
        condition AnnounceActivity, var("activity"), object: var("object")
        none CreateActivity, object: var("object")
        none AnnounceActivity, not(var("activity")), object: var("object")
        any Timeline, owner: var("actor"), object: var("object")
        retract Timeline, owner: var("actor"), object: var("object")
      end
    end
  end

  def run(actor, activity)
    School::Fact.clear!

    raise "actor must be local" unless actor.local?

    domain.assert(IsAddressedTo.new(activity, actor))

    5.times do |i|
      break if domain.run == School::Domain::Status::Completed
      raise "iteration limit exceeded" if i >= 4
    end
  end
end
