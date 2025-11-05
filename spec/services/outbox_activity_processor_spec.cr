require "../spec_helper/base"
require "../spec_helper/factory"
require "../../src/services/outbox_activity_processor"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/accept"
require "../../src/models/activity_pub/activity/reject"
require "../../src/models/activity_pub/activity/undo"
require "../../src/models/activity_pub/activity/delete"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/create"
require "../../src/models/relationship/social/follow"

Spectator.describe OutboxActivityProcessor do
  setup_spec

  let(account) { register }
  let_create(:actor, named: :other)
  let_create(:object, attributed_to: other)

  class MockDeliverTask < Task::Deliver
    class_property schedule_called_count : Int32 = 0
    class_property last_sender : ActivityPub::Actor?
    class_property last_activity : ActivityPub::Activity?

    def self.reset!
      self.schedule_called_count = 0
      self.last_sender = nil
      self.last_activity = nil
    end

    def initialize(sender : ActivityPub::Actor, activity : ActivityPub::Activity)
      super(sender: sender, activity: activity)
      self.class.last_sender = sender
      self.class.last_activity = activity
    end

    def schedule(next_attempt_at = nil)
      self.class.schedule_called_count += 1
      # don't save to database
      self
    end
  end

  before_each do
    MockDeliverTask.reset!
  end

  describe ".process" do
    context "with a Follow activity" do
      let_create(:follow, named: :follow_activity, actor: account.actor, object: other)

      it "creates a follow relationship" do
        expect { OutboxActivityProcessor.process(account, follow_activity, ContentRules.new, MockDeliverTask) }.
          to change { Relationship::Social::Follow.count }.by(1)
      end

      it "sets the relationship as unconfirmed" do
        OutboxActivityProcessor.process(account, follow_activity, ContentRules.new, MockDeliverTask)
        follow = Relationship::Social::Follow.find?(actor: account.actor, object: other)
        expect(follow.try(&.confirmed)).to be_false
      end

      it "schedules deliver task" do
        OutboxActivityProcessor.process(account, follow_activity, ContentRules.new, MockDeliverTask)
        expect(MockDeliverTask.schedule_called_count).to eq(1)
        expect(MockDeliverTask.last_sender).to eq(account.actor)
        expect(MockDeliverTask.last_activity).to eq(follow_activity)
      end

      context "given an existing relationship" do
        let_create!(:follow_relationship, actor: account.actor, object: other, visible: false)

        it "does not create a duplicate relationship" do
          expect { OutboxActivityProcessor.process(account, follow_activity, ContentRules.new, MockDeliverTask) }.
            not_to change { Relationship::Social::Follow.count }
        end
      end
    end

    context "with an Accept activity" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)
      let_create(:follow_relationship, actor: other, object: account.actor, confirmed: false)
      let_create(:accept, named: :accept_activity, actor: account.actor, object: follow_activity)

      it "confirms the follow relationship" do
        expect { OutboxActivityProcessor.process(account, accept_activity, ContentRules.new, MockDeliverTask) }.
          to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end

      it "schedules deliver task" do
        OutboxActivityProcessor.process(account, accept_activity, ContentRules.new, MockDeliverTask)
        expect(MockDeliverTask.schedule_called_count).to eq(1)
        expect(MockDeliverTask.last_sender).to eq(account.actor)
        expect(MockDeliverTask.last_activity).to eq(accept_activity)
      end
    end

    context "with a Reject activity" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)
      let_create(:follow_relationship, actor: other, object: account.actor, confirmed: false)
      let_create(:reject, named: :reject_activity, actor: account.actor, object: follow_activity)

      it "confirms the follow relationship" do
        expect { OutboxActivityProcessor.process(account, reject_activity, ContentRules.new, MockDeliverTask) }.
          to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end

      it "schedules deliver task" do
        OutboxActivityProcessor.process(account, reject_activity, ContentRules.new, MockDeliverTask)
        expect(MockDeliverTask.schedule_called_count).to eq(1)
        expect(MockDeliverTask.last_sender).to eq(account.actor)
        expect(MockDeliverTask.last_activity).to eq(reject_activity)
      end
    end

    context "with an Undo activity" do
      context "given a Follow" do
        let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
        let_create!(:follow_relationship, actor: account.actor, object: other)
        let_create(:undo, named: :undo_activity, actor: account.actor, object: follow_activity)

        pre_condition { expect(follow_relationship).not_to be_nil }

        it "destroys the follow relationship" do
          expect { OutboxActivityProcessor.process(account, undo_activity, ContentRules.new, MockDeliverTask) }.
            to change { Relationship::Social::Follow.count }.by(-1)
        end

        it "marks the follow activity as undone" do
          expect { OutboxActivityProcessor.process(account, undo_activity, ContentRules.new, MockDeliverTask) }.
            to change { follow_activity.reload!.undone_at }.from(nil)
        end

        it "schedules deliver task" do
          OutboxActivityProcessor.process(account, undo_activity, ContentRules.new, MockDeliverTask)
          expect(MockDeliverTask.schedule_called_count).to eq(1)
          expect(MockDeliverTask.last_sender).to eq(account.actor)
          expect(MockDeliverTask.last_activity).to eq(undo_activity)
        end
      end

      context "given an Announce" do
        let_create(:announce, named: :announce_activity, actor: account.actor, object: object)
        let_create(:undo, named: :undo_activity, actor: account.actor, object: announce_activity)

        it "marks the announce activity as undone" do
          expect { OutboxActivityProcessor.process(account, undo_activity, ContentRules.new, MockDeliverTask) }.
            to change { announce_activity.reload!.undone_at }.from(nil)
        end

        it "schedules deliver task" do
          OutboxActivityProcessor.process(account, undo_activity, ContentRules.new, MockDeliverTask)
          expect(MockDeliverTask.schedule_called_count).to eq(1)
          expect(MockDeliverTask.last_sender).to eq(account.actor)
          expect(MockDeliverTask.last_activity).to eq(undo_activity)
        end
      end
    end

    context "with a Delete activity" do
      context "given an Object" do
        let_create(:object, named: :object_to_delete, attributed_to: account.actor)
        let_create(:delete, named: :delete_activity, actor: account.actor, object: object_to_delete)

        it "marks the object as deleted" do
          expect { OutboxActivityProcessor.process(account, delete_activity, ContentRules.new, MockDeliverTask) }.
            to change { object_to_delete.reload!.deleted_at }.from(nil)
        end

        it "schedules deliver task" do
          OutboxActivityProcessor.process(account, delete_activity, ContentRules.new, MockDeliverTask)
          expect(MockDeliverTask.schedule_called_count).to eq(1)
          expect(MockDeliverTask.last_sender).to eq(account.actor)
          expect(MockDeliverTask.last_activity).to eq(delete_activity)
        end
      end

      context "given an Actor" do
        let_create(:delete, named: :delete_activity, actor: account.actor, object: account.actor)

        it "marks the actor as deleted" do
          expect { OutboxActivityProcessor.process(account, delete_activity, ContentRules.new, MockDeliverTask) }.
            to change { account.actor.reload!.deleted_at }.from(nil)
        end

        it "schedules deliver task" do
          OutboxActivityProcessor.process(account, delete_activity, ContentRules.new, MockDeliverTask)
          expect(MockDeliverTask.schedule_called_count).to eq(1)
          expect(MockDeliverTask.last_sender).to eq(account.actor)
          expect(MockDeliverTask.last_activity).to eq(delete_activity)
        end
      end
    end

    context "with Create activity" do
      let_create(:create, named: :create_activity, actor: account.actor, object: object)

      it "schedules deliver task" do
        OutboxActivityProcessor.process(account, create_activity, ContentRules.new, MockDeliverTask)
        expect(MockDeliverTask.schedule_called_count).to eq(1)
        expect(MockDeliverTask.last_sender).to eq(account.actor)
        expect(MockDeliverTask.last_activity).to eq(create_activity)
      end
    end

    context "with Announce activity" do
      let_create(:announce, named: :announce_activity, actor: account.actor, object: object)

      it "schedules deliver task" do
        OutboxActivityProcessor.process(account, announce_activity, ContentRules.new, MockDeliverTask)
        expect(MockDeliverTask.schedule_called_count).to eq(1)
        expect(MockDeliverTask.last_sender).to eq(account.actor)
        expect(MockDeliverTask.last_activity).to eq(announce_activity)
      end
    end
  end
end
