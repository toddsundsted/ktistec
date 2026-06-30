require "../../src/services/actor_update_distributor"
require "../../src/models/relationship/content/outbox"

require "../spec_helper/base"
require "../spec_helper/factory"
require "../spec_helper/mock"

# raises while scheduling delivery, to exercise the best-effort contract
class RaisingDeliverTask < Task::Deliver
  def initialize(sender : ActivityPub::Actor, activity : ActivityPub::Activity, recipients : Array(String)? = nil)
    super(sender: sender, activity: activity, recipients: recipients)
    raise "boom"
  end
end

Spectator.describe ActorUpdateDistributor do
  setup_spec

  let(account) { register }

  before_each { MockDeliverTask.reset! }

  describe ".distribute" do
    it "adds an Update to the actor's outbox" do
      expect { ActorUpdateDistributor.distribute(account, deliver_task_class: MockDeliverTask) }
        .to change { Relationship::Content::Outbox.count(owner: account.actor) }.by(1)
    end

    it "distributes an Update whose object is the actor" do
      ActorUpdateDistributor.distribute(account, deliver_task_class: MockDeliverTask)
      activity = MockDeliverTask.last_activity.not_nil!
      expect(activity).to be_a(ActivityPub::Activity::Update)
      expect(activity.object_iri).to eq(account.actor.iri)
    end

    it "addresses the update to the public collection" do
      ActorUpdateDistributor.distribute(account, deliver_task_class: MockDeliverTask)
      expect(MockDeliverTask.last_activity.not_nil!.to).to contain(Ktistec::Constants::PUBLIC)
    end

    it "addresses the update to the followers collection" do
      ActorUpdateDistributor.distribute(account, deliver_task_class: MockDeliverTask)
      expect(MockDeliverTask.last_activity.not_nil!.cc).to contain(account.actor.followers)
    end

    context "with a remote follower" do
      let_create!(:actor, named: :follower)

      before_each { do_follow(follower, account.actor) }

      it "schedules delivery to the follower" do
        ActorUpdateDistributor.distribute(account, deliver_task_class: MockDeliverTask)
        expect(MockDeliverTask.last_recipients).to contain(follower.iri)
      end
    end

    context "when delivery fails" do
      it "does not propagate the error" do
        expect { ActorUpdateDistributor.distribute(account, deliver_task_class: RaisingDeliverTask) }
          .not_to raise_error
      end
    end
  end
end
