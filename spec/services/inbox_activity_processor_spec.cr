require "../spec_helper/base"
require "../spec_helper/factory"
require "../../src/services/inbox_activity_processor"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/accept"
require "../../src/models/activity_pub/activity/reject"
require "../../src/models/activity_pub/activity/undo"
require "../../src/models/activity_pub/activity/delete"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/create"
require "../../src/models/relationship/social/follow"

Spectator.describe InboxActivityProcessor do
  setup_spec

  let(account) { register }
  let_create(:actor, named: :other)
  let_create(:object, attributed_to: other)

  class MockHandleFollowRequestTask < Task::HandleFollowRequest
    class_property schedule_called_count : Int32 = 0
    class_property last_recipient : ActivityPub::Actor?
    class_property last_activity : ActivityPub::Activity::Follow?

    def self.reset!
      self.schedule_called_count = 0
      self.last_recipient = nil
      self.last_activity = nil
    end

    def initialize(recipient : ActivityPub::Actor, activity : ActivityPub::Activity::Follow)
      super(recipient: recipient, activity: activity)
      self.class.last_recipient = recipient
      self.class.last_activity = activity
    end

    def schedule(next_attempt_at = nil)
      self.class.schedule_called_count += 1
      # don't save to database
      self
    end
  end

  class MockHandleFollowBackTask < Task::HandleFollowBack
    class_property schedule_called_count : Int32 = 0
    class_property last_recipient : ActivityPub::Actor?
    class_property last_activity : ActivityPub::Activity::Follow?

    def self.reset!
      self.schedule_called_count = 0
      self.last_recipient = nil
      self.last_activity = nil
    end

    def initialize(recipient : ActivityPub::Actor, activity : ActivityPub::Activity::Follow)
      super(recipient: recipient, activity: activity)
      self.class.last_recipient = recipient
      self.class.last_activity = activity
    end

    def schedule(next_attempt_at = nil)
      self.class.schedule_called_count += 1
      # don't save to database
      self
    end
  end

  class MockReceiveTask < Task::Receive
    class_property schedule_called_count : Int32 = 0
    class_property last_receiver : ActivityPub::Actor?
    class_property last_activity : ActivityPub::Activity?
    class_property last_deliver_to : Array(String)?

    def self.reset!
      self.schedule_called_count = 0
      self.last_receiver = nil
      self.last_activity = nil
      self.last_deliver_to = nil
    end

    def initialize(receiver : ActivityPub::Actor, activity : ActivityPub::Activity, deliver_to : Array(String)? = nil)
      super(receiver: receiver, activity: activity)
      self.deliver_to = deliver_to if deliver_to
      self.class.last_receiver = receiver
      self.class.last_activity = activity
      self.class.last_deliver_to = deliver_to
    end

    def schedule(next_attempt_at = nil)
      self.class.schedule_called_count += 1
      # don't save to database
      self
    end
  end

  before_each do
    MockHandleFollowRequestTask.reset!
    MockHandleFollowBackTask.reset!
    MockReceiveTask.reset!
  end

  describe ".process" do
    context "with a Follow activity" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)

      it "creates a follow relationship" do
        expect { InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
          to change { Relationship::Social::Follow.count }.by(1)
      end

      context "given another actor" do
        let_build(:actor, named: other_actor)

        before_each { follow_activity.assign(object: other_actor).save }

        it "does not create a follow relationship" do
          expect { InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            not_to change { Relationship::Social::Follow.count }
        end
      end

      it "sets the relationship as unconfirmed" do
        InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        follow = Relationship::Social::Follow.find?(actor: other, object: account.actor)
        expect(follow.try(&.confirmed)).to be_false
      end

      it "passes deliver_to to receive task" do
        deliver_to = ["https://example.com/followers"]
        InboxActivityProcessor.process(account, follow_activity, deliver_to, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockReceiveTask.last_deliver_to).to eq(deliver_to)
      end

      it "schedules handle follow request task" do
        InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockHandleFollowRequestTask.schedule_called_count).to eq(1)
        expect(MockHandleFollowRequestTask.last_recipient).to eq(account.actor)
        expect(MockHandleFollowRequestTask.last_activity).to eq(follow_activity)
      end

      it "schedules handle follow back task" do
        InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockHandleFollowBackTask.schedule_called_count).to eq(1)
        expect(MockHandleFollowBackTask.last_recipient).to eq(account.actor)
        expect(MockHandleFollowBackTask.last_activity).to eq(follow_activity)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(follow_activity)
      end

      context "given an existing relationship" do
        let_create!(:follow_relationship, actor: other, object: account.actor, visible: false)

        it "does not create a duplicate relationship" do
          expect { InboxActivityProcessor.process(account, follow_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            not_to change { Relationship::Social::Follow.count }
        end
      end
    end

    context "with an Accept activity" do
      let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
      let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
      let_create(:accept, named: :accept_activity, actor: other, object: follow_activity)

      it "confirms the follow relationship" do
        expect { InboxActivityProcessor.process(account, accept_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
          to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, accept_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(accept_activity)
      end
    end

    context "with a Reject activity" do
      let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
      let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
      let_create(:reject, named: :reject_activity, actor: other, object: follow_activity)

      it "confirms the follow relationship" do
        expect { InboxActivityProcessor.process(account, reject_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
          to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, reject_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(reject_activity)
      end
    end

    context "with an Undo activity" do
      context "given a Follow" do
        let_create(:follow, named: :follow_activity, actor: other, object: account.actor)
        let_create!(:follow_relationship, actor: other, object: account.actor)
        let_create(:undo, named: :undo_activity, actor: other, object: follow_activity)

        pre_condition { expect(follow_relationship).not_to be_nil }

        it "destroys the follow relationship" do
          expect { InboxActivityProcessor.process(account, undo_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            to change { Relationship::Social::Follow.count }.by(-1)
        end

        it "marks the follow activity as undone" do
          expect { InboxActivityProcessor.process(account, undo_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            to change { follow_activity.reload!.undone_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, undo_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(undo_activity)
        end
      end

      context "given an Announce" do
        let_create(:announce, named: :announce_activity, actor: other, object: object)
        let_create(:undo, named: :undo_activity, actor: other, object: announce_activity)

        it "marks the announce activity as undone" do
          expect { InboxActivityProcessor.process(account, undo_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            to change { announce_activity.reload!.undone_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, undo_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(undo_activity)
        end
      end
    end

    context "with a Delete activity" do
      context "given an Object" do
        let_create(:object, named: :object_to_delete, attributed_to: other)
        let_create(:delete, named: :delete_activity, actor: other, object: object_to_delete)

        it "marks the object as deleted" do
          expect { InboxActivityProcessor.process(account, delete_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            to change { object_to_delete.reload!.deleted_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, delete_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(delete_activity)
        end
      end

      context "given an Actor" do
        let_create(:delete, named: :delete_activity, actor: other, object: other)

        it "marks the actor as deleted" do
          expect { InboxActivityProcessor.process(account, delete_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask) }.
            to change { other.reload!.deleted_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, delete_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(delete_activity)
        end
      end
    end

    context "with Create activity" do
      let_create(:create, named: :create_activity, actor: other, object: object)

      it "schedules receive task" do
        InboxActivityProcessor.process(account, create_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(create_activity)
      end
    end

    context "with Announce activity" do
      let_create(:announce, named: :announce_activity, actor: other, object: object)

      it "schedules receive task" do
        InboxActivityProcessor.process(account, announce_activity, nil, ContentRules.new, MockHandleFollowRequestTask, MockHandleFollowBackTask, MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(announce_activity)
      end
    end
  end
end
