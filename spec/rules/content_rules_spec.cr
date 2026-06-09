require "../../src/rules/content_rules"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe ContentRules do
  alias Notification = ::Relationship::Content::Notification
  alias Timeline = ::Relationship::Content::Timeline

  setup_spec

  {% if flag?(:"school:metrics") %}
    before_all do
      School::Metrics.reset
    end
    after_all do
      metrics = School::Metrics.metrics
      puts
      puts "runs:            #{metrics[:runs]}"
      puts "rules:           #{metrics[:rules]}"
      puts "conditions:      #{metrics[:conditions]}"
      puts "conditions/run:  #{metrics[:conditions_per_run]}"
      puts "conditions/rule: #{metrics[:conditions_per_rule]}"
      puts "operations:      #{metrics[:operations]}"
      puts "operations/run:  #{metrics[:operations_per_run]}"
      puts "operations/rule: #{metrics[:operations_per_rule]}"
      puts "runtime:         #{metrics[:runtime]}"
    end
  {% end %}

  describe ".new" do
    it "creates an instance" do
      expect(described_class.new).to be_a(ContentRules)
    end
  end

  let(owner) { register.actor }

  let_build(:actor, named: other)
  let_build(:object, attributed_to: other)
  let_create(:create, actor: other, object: object)
  let_create(:update, actor: other, object: object)
  let_create(:announce, actor: other, object: object)
  let_create(:follow, actor: other, object: owner)
  let_create(:delete, actor: other, object: object)
  let_create(:undo, actor: other)

  subject { described_class.new }

  # outbox

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::Outgoing.new(owner, activity)
      end
    end

    context "given an empty outbox" do
      pre_condition { expect(owner.in_outbox(public: false)).to be_empty }

      it "adds the activity to the outbox" do
        run(owner, create)
        expect(owner.in_outbox(public: false)).to eq([create])
      end
    end
  end

  # inbox

  describe "#run" do
    let(recipients) { [] of String }

    def run(owner, activity)
      subject.run do
        recipients.compact.each { |recipient| assert ContentRules::IsRecipient.new(recipient) }
        assert ContentRules::Incoming.new(owner, activity)
      end
    end

    context "given an empty inbox" do
      pre_condition { expect(owner.in_inbox(public: false)).to be_empty }

      it "does not add the activity to the inbox" do
        run(owner, create)
        expect(owner.in_inbox(public: false)).to be_empty
      end

      context "owner in recipients" do
        let(recipients) { [owner.iri] }

        it "adds the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to eq([create])
        end
      end

      context "public URL in recipients" do
        let(recipients) { ["https://www.w3.org/ns/activitystreams#Public"] }

        it "does not add the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to be_empty
        end

        context "and owner is follows activity's actor" do
          before_each do
            owner.follow(create.actor).save
          end

          it "adds the activity to the inbox" do
            run(owner, create)
            expect(owner.in_inbox(public: false)).to eq([create])
          end
        end
      end

      context "followers collection in recipients" do
        let(recipients) { [create.actor.followers] }

        it "does not add the activity to the inbox" do
          run(owner, create)
          expect(owner.in_inbox(public: false)).to be_empty
        end

        context "and owner is follows activity's actor" do
          before_each do
            owner.follow(create.actor).save
          end

          it "adds the activity to the inbox" do
            run(owner, create)
            expect(owner.in_inbox(public: false)).to eq([create])
          end
        end
      end
    end
  end

  # notifications

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::Incoming.new(owner, activity)
        assert ContentRules::InMailboxOf.new(activity, owner)
      end
    end

    # temporary stub to make it easier to transition the tests that follow
    class ::Relationship::Content::Notification
      def object_or_activity
        if self.responds_to?(:object)
          self.object
        elsif self.responds_to?(:activity)
          self.activity
        end
      end
    end

    context "given no notifications" do
      pre_condition { expect(owner.notifications).to be_empty }

      it "does not add the create to the notifications" do
        run(owner, create)
        expect(owner.notifications).to be_empty
      end

      it "adds the follow to the notifications" do
        run(owner, follow)
        expect(owner.notifications.map(&.object_or_activity)).to eq([follow])
      end

      context "object mentions the owner" do
        let_build(:mention, name: owner.iri, href: owner.iri)

        before_each do
          object.assign(mentions: [mention])
        end

        it "adds the object to the notifications" do
          run(owner, create)
          expect(owner.notifications.map(&.object_or_activity)).to have(object)
        end

        it "adds the object to the notifications" do
          run(owner, update)
          expect(owner.notifications.map(&.object_or_activity)).to have(object)
        end

        context "and is attributed to the owner" do
          before_each { object.assign(attributed_to: owner) }

          it "does not add the object to the notifications" do
            run(owner, create)
            expect(owner.notifications.map(&.object_or_activity)).not_to have(object)
          end

          it "does not add the object to the notifications" do
            run(owner, update)
            expect(owner.notifications.map(&.object_or_activity)).not_to have(object)
          end
        end
      end

      context "object mentions another actor" do
        let_build(:mention, name: other.iri, href: other.iri)

        before_each do
          object.assign(mentions: [mention])
        end

        it "does not add the object to the notifications" do
          run(owner, create)
          expect(owner.notifications.map(&.object_or_activity)).not_to have(object)
        end
      end

      context "another object mentions the owner" do
        let_build(:mention, name: owner.iri, href: owner.iri)
        let_create!(:object, named: nil, mentions: [mention])

        it "does not add the object to the notifications" do
          run(owner, create)
          expect(owner.notifications.map(&.object_or_activity)).not_to have(object)
        end
      end

      context "object is in reply to an object attributed to the owner" do
        let_build(:object, named: parent, attributed_to: owner)

        before_each do
          object.assign(in_reply_to: parent)
        end

        it "adds the reply to the notifications" do
          run(owner, create)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end

        it "adds the object to the notifications" do
          run(owner, update)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end

        context "and is attributed to the owner" do
          before_each { object.assign(attributed_to: owner) }

          it "does not add the object to the notifications" do
            run(owner, create)
            expect(owner.notifications.map(&.object_or_activity)).to be_empty
          end

          it "does not add the object to the notifications" do
            run(owner, update)
            expect(owner.notifications.map(&.object_or_activity)).to be_empty
          end
        end
      end

      context "object is in reply to an object attributed to another actor" do
        let_build(:object, named: parent, attributed_to: other)

        before_each do
          object.assign(in_reply_to: parent)
        end

        it "does not add the reply to the notifications" do
          run(owner, create)
          expect(owner.notifications).to be_empty
        end
      end

      context "another object is in reply to an object attributed to the owner" do
        let_build(:object, named: parent, attributed_to: owner)
        let_create!(:object, named: nil, in_reply_to: parent)

        it "does not add the reply to the notifications" do
          run(owner, create)
          expect(owner.notifications).to be_empty
        end
      end

      context "object both is in reply to an object attributed to the owner and mentions the owner" do
        let_build(:object, named: parent, attributed_to: owner)
        let_build(:mention, name: owner.iri, href: owner.iri)

        before_each do
          object.assign(in_reply_to: parent, mentions: [mention])
        end

        it "adds the object to the notifications once" do
          run(owner, create)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end

        it "gives preference to the reply notification" do
          run(owner, create)
          expect(owner.notifications.map(&.class)).to eq([Relationship::Content::Notification::Reply])
        end
      end

      context "object is a reply" do
        let_build(:object, named: origin, attributed_to: other)

        before_each do
          object.assign(in_reply_to: origin).save
        end

        it "does not add any notifications" do
          run(owner, create)
          expect(owner.notifications).to be_empty
        end
      end

      context "follow does not follow the owner" do
        before_each { follow.assign(object: other).save }

        it "does not add the follow to the notifications" do
          run(owner, follow)
          expect(owner.notifications).to be_empty
        end
      end
    end

    context "given notifications with mention added via create" do
      before_each do
        put_in_notifications(owner, mention: create)
      end

      pre_condition { expect(owner.notifications.map(&.object_or_activity)).to eq([object]) }

      it "does not add the mention to the notifications" do
        run(owner, create)
        expect(owner.notifications.map(&.object_or_activity)).to eq([object])
      end

      it "removes the mention from the notifications" do
        run(owner, delete)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      context "and an unrelated delete" do
        let_create(:delete, named: unrelated)

        it "does not remove the mention from the notifications" do
          run(owner, unrelated)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end
      end

      context "and an unrelated undo" do
        before_each { undo.assign(object: announce).save }

        it "does not remove the mention from the notifications" do
          run(owner, undo)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end
      end
    end

    context "given notifications with mention added via update" do
      before_each do
        put_in_notifications(owner, mention: update)
      end

      pre_condition { expect(owner.notifications.map(&.object_or_activity)).to eq([object]) }

      it "removes the mention from the notifications" do
        run(owner, delete)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      context "and an unrelated delete" do
        let_create(:delete, named: unrelated)

        it "does not remove the mention from the notifications" do
          run(owner, unrelated)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end
      end
    end

    context "given notifications with reply added via create" do
      before_each do
        put_in_notifications(owner, reply: create)
      end

      pre_condition { expect(owner.notifications.map(&.object_or_activity)).to eq([object]) }

      it "does not add the reply to the notifications" do
        run(owner, create)
        expect(owner.notifications.map(&.object_or_activity)).to eq([object])
      end

      it "removes the reply from the notifications" do
        run(owner, delete)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      context "and an unrelated delete" do
        let_create(:delete, named: unrelated)

        it "does not remove the reply from the notifications" do
          run(owner, unrelated)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end
      end

      context "and an unrelated undo" do
        before_each { undo.assign(object: announce).save }

        it "does not remove the reply from the notifications" do
          run(owner, undo)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end
      end
    end

    context "given notifications with reply added via update" do
      before_each do
        put_in_notifications(owner, reply: update)
      end

      pre_condition { expect(owner.notifications.map(&.object_or_activity)).to eq([object]) }

      it "removes the reply from the notifications" do
        run(owner, delete)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      context "and an unrelated delete" do
        let_create(:delete, named: unrelated)

        it "does not remove the reply from the notifications" do
          run(owner, unrelated)
          expect(owner.notifications.map(&.object_or_activity)).to eq([object])
        end
      end
    end

    context "given notifications with follow already added" do
      before_each do
        undo.assign(object: follow).save
        put_in_notifications(owner, follow)
      end

      pre_condition { expect(owner.notifications.map(&.object_or_activity)).to eq([follow]) }

      it "does not add the follow to the notifications" do
        run(owner, follow)
        expect(owner.notifications.map(&.object_or_activity)).to eq([follow])
      end

      it "removes the follow from the notifications" do
        run(owner, undo)
        expect(Notification.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the follow from the notifications" do
        run(owner, delete)
        expect(owner.notifications.map(&.object_or_activity)).to eq([follow])
      end
    end
  end

  # timeline

  describe "#run" do
    def run(owner, activity)
      put_in_inbox(owner, activity)
      subject.run do
        assert ContentRules::Incoming.new(owner, activity)
        assert ContentRules::InMailboxOf.new(activity, owner)
      end
    end

    context "given an empty timeline" do
      pre_condition { expect(owner.timeline).to be_empty }

      it "adds the object to the timeline" do
        run(owner, create)
        expect(owner.timeline.map(&.object)).to eq([object])
      end

      it "adds the object to the timeline" do
        run(owner, announce)
        expect(owner.timeline.map(&.object)).to eq([object])
      end

      context "object is a reply" do
        let_build(:object, named: :original, attributed_to: owner)

        before_each { object.in_reply_to = original }

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to be_empty
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        context "but is attributed to the owner" do
          before_each do
            object.assign(attributed_to: owner).save
          end

          it "adds the object to the timeline" do
            run(owner, create)
            expect(owner.timeline.map(&.object)).to eq([object])
          end
        end
      end

      context "another object is a reply" do
        let_build(:object, named: :another, attributed_to: owner)

        before_each { another.in_reply_to = object }

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end
      end

      context "object mentions the owner" do
        let_build(:mention, name: owner.iri, href: owner.iri)

        before_each do
          object.assign(mentions: [mention])
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end
      end

      context "object mentions the owner and another actor" do
        let_build(:mention, named: owner_mention, name: owner.iri, href: owner.iri)
        let_build(:mention, named: other_mention, name: other.iri, href: other.iri)

        before_each do
          object.assign(mentions: [owner_mention, other_mention])
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end
      end

      context "object mentions another actor" do
        let_build(:mention, name: other.iri, href: other.iri)

        before_each do
          object.assign(mentions: [mention])
        end

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to be_empty
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        context "but is attributed to the owner" do
          before_each do
            object.assign(attributed_to: owner).save
          end

          it "adds the object to the timeline" do
            run(owner, create)
            expect(owner.timeline.map(&.object)).to eq([object])
          end
        end
      end
    end

    context "given a timeline with an object already added" do
      pre_condition { expect(owner.timeline.map(&.object)).to eq([object]) }

      context "and an associated create" do
        before_each do
          put_in_timeline_create(owner, object)
          put_in_inbox(owner, create)
        end

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "removes the object from the timeline" do
          run(owner, delete)
          expect(Timeline.where(from_iri: owner.iri)).to be_empty
        end

        context "and an unrelated delete" do
          let_create(:delete, named: unrelated)

          it "does not remove the object from the timeline" do
            run(owner, unrelated)
            expect(owner.timeline.map(&.object)).to eq([object])
          end
        end

        context "and an unrelated undo" do
          before_each { undo.assign(object: announce).save }

          it "does not remove the object from the timeline" do
            run(owner, undo)
            expect(owner.timeline.map(&.object)).to eq([object])
          end
        end
      end

      context "and an associated announce" do
        before_each do
          put_in_timeline_announce(owner, object)
          put_in_inbox(owner, announce)
        end

        it "does not add the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "removes the object from the timeline" do
          run(owner, delete)
          expect(Timeline.where(from_iri: owner.iri)).to be_empty
        end

        context "and a related undo" do
          before_each { undo.assign(object: announce).save }

          it "removes the object from the timeline" do
            run(owner, undo)
            expect(Timeline.where(from_iri: owner.iri)).to be_empty
          end

          context "with a create in the database but not in a mailbox" do
            before_each { create.save }

            it "removes the object from the timeline" do
              run(owner, undo)
              expect(Timeline.where(from_iri: owner.iri)).to be_empty
            end
          end

          context "and another announce" do
            let_create!(:announce, named: another, actor: owner, object: object)

            it "does not remove the object from the timeline" do
              run(owner, undo)
              expect(owner.timeline.map(&.object)).to eq([object])
            end

            context "that has been undone" do
              before_each { another.undo! }

              it "removes the object from the timeline" do
                run(owner, undo)
                expect(Timeline.where(from_iri: owner.iri)).to be_empty
              end
            end
          end
        end
      end
    end

    context "given a timeline with another object already added" do
      let_build(:object, named: another)
      let_create!(:create, object: another)

      before_each do
        put_in_inbox(owner, create)
        put_in_timeline_create(owner, another)
      end

      pre_condition { expect(owner.timeline.map(&.object)).to eq([another]) }

      it "does not remove the object from the timeline" do
        run(owner, delete)
        expect(owner.timeline.map(&.object)).to eq([another])
      end

      it "does not remove the object from the timeline" do
        run(owner, undo)
        expect(owner.timeline.map(&.object)).to eq([another])
      end
    end

    # currently, the following should never happen, but if the object
    # has been deleted, remove the corresponding timeline entry.

    context "given a timeline with an object that has been deleted" do
      before_each do
        put_in_timeline_create(owner, object)
        object.delete!
      end

      pre_condition do
        expect(Timeline.where(from_iri: owner.iri)).not_to be_empty
      end

      # a copy without the associations
      let(delete_fresh) { ActivityPub::Activity::Delete.find(delete.id) }

      it "destroys the timeline entry" do
        run(owner, delete_fresh)
        expect(Timeline.where(from_iri: owner.iri)).to be_empty
      end
    end
  end

  # content filters / outgoing

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::Outgoing.new(owner, activity)
      end
    end

    before_each do
      create.assign(actor: owner).save
      announce.assign(actor: owner).save
    end

    context "given an empty timeline" do
      pre_condition { expect(owner.timeline).to be_empty }

      it "adds the object to the timeline" do
        run(owner, create)
        expect(owner.timeline.map(&.object)).to eq([object])
      end

      it "adds the object to the timeline" do
        run(owner, announce)
        expect(owner.timeline.map(&.object)).to eq([object])
      end

      context "given a content filter" do
        let_create!(:filter_term, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end
      end

      context "given a content filter of the actor" do
        let_create!(:filter_term, actor: owner, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end
      end
    end
  end

  # content filters / incoming

  describe "#run" do
    def run(owner, activity)
      subject.run do
        assert ContentRules::IsRecipient.new(owner.iri)
        assert ContentRules::Incoming.new(owner, activity)
      end
    end

    pre_condition do
      expect(create.actor).not_to eq(owner)
      expect(announce.actor).not_to eq(owner)
    end

    context "given an empty timeline" do
      pre_condition { expect(owner.timeline).to be_empty }

      it "adds the object to the timeline" do
        run(owner, create)
        expect(owner.timeline.map(&.object)).to eq([object])
      end

      it "adds the object to the timeline" do
        run(owner, announce)
        expect(owner.timeline.map(&.object)).to eq([object])
      end

      context "given a content filter" do
        let_create!(:filter_term, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "adds the object to the timeline" do
          run(owner, create)
          expect(owner.timeline.map(&.object)).to eq([object])
        end

        it "adds the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline.map(&.object)).to eq([object])
        end
      end

      context "given a content filter of the actor" do
        let_create!(:filter_term, actor: owner, term: "%content%")

        before_each do
          object.assign(content: "<span class='capitalize'>c</span>ontent blah blah").save
        end

        it "does not add the object to the timeline" do
          run(owner, create)
          expect(owner.timeline).to be_empty
        end

        it "does not add the object to the timeline" do
          run(owner, announce)
          expect(owner.timeline).to be_empty
        end
      end
    end
  end
end
