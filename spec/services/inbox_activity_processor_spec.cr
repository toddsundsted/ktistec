require "../../src/services/inbox_activity_processor"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/accept"
require "../../src/models/activity_pub/activity/reject"
require "../../src/models/activity_pub/activity/undo"
require "../../src/models/activity_pub/activity/delete"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/create"
require "../../src/models/relationship/social/follow"

require "../spec_helper/base"
require "../spec_helper/factory"
require "../spec_helper/mock"

Spectator.describe InboxActivityProcessor do
  setup_spec

  let(account) { register }
  let_create(:actor, named: :other)
  let_create(:object, attributed_to: other)

  before_each do
    MockHandleFollowRequestTask.reset!
    MockReceiveTask.reset!
    MockDeliverTask.reset!
  end

  describe ".process" do
    context "with a Follow activity" do
      let_create(:follow, named: :follow_activity, actor: other, object: account.actor)

      it "creates a follow relationship" do
        expect { InboxActivityProcessor.process(account, follow_activity) }
          .to change { Relationship::Social::Follow.count }.by(1)
      end

      context "given another actor" do
        let_build(:actor, named: other_actor)

        before_each { follow_activity.assign(object: other_actor).save }

        it "does not create a follow relationship" do
          expect { InboxActivityProcessor.process(account, follow_activity) }
            .not_to change { Relationship::Social::Follow.count }
        end
      end

      it "sets the relationship as unconfirmed" do
        InboxActivityProcessor.process(account, follow_activity)
        follow = Relationship::Social::Follow.find?(actor: other, object: account.actor)
        expect(follow.try(&.confirmed)).to be_false
      end

      it "passes deliver_to to receive task" do
        deliver_to = ["https://example.com/followers"]
        InboxActivityProcessor.process(account, follow_activity, deliver_to, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.last_deliver_to).to eq(deliver_to)
      end

      it "schedules handle follow request task" do
        InboxActivityProcessor.process(account, follow_activity, handle_follow_request_task_class: MockHandleFollowRequestTask)
        expect(MockHandleFollowRequestTask.schedule_called_count).to eq(1)
        expect(MockHandleFollowRequestTask.last_recipient).to eq(account.actor)
        expect(MockHandleFollowRequestTask.last_activity).to eq(follow_activity)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, follow_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(follow_activity)
      end

      context "given an existing relationship" do
        let_create!(:follow_relationship, actor: other, object: account.actor, visible: false)

        it "does not create a duplicate relationship" do
          expect { InboxActivityProcessor.process(account, follow_activity) }
            .not_to change { Relationship::Social::Follow.count }
        end
      end
    end

    context "with an Accept activity" do
      let_create(:follow, named: :follow_activity, actor: account.actor, object: other)
      let_create(:follow_relationship, actor: account.actor, object: other, confirmed: false)
      let_create(:accept, named: :accept_activity, actor: other, object: follow_activity)

      it "confirms the follow relationship" do
        expect { InboxActivityProcessor.process(account, accept_activity) }
          .to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, accept_activity, receive_task_class: MockReceiveTask)
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
        expect { InboxActivityProcessor.process(account, reject_activity) }
          .to change { follow_relationship.reload!.confirmed }.from(false).to(true)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, reject_activity, receive_task_class: MockReceiveTask)
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
          expect { InboxActivityProcessor.process(account, undo_activity) }
            .to change { Relationship::Social::Follow.count }.by(-1)
        end

        it "marks the follow activity as undone" do
          expect { InboxActivityProcessor.process(account, undo_activity) }
            .to change { follow_activity.reload!.undone_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(undo_activity)
        end
      end

      context "given an Announce" do
        let_create(:announce, named: :announce_activity, actor: other, object: object)
        let_create(:undo, named: :undo_activity, actor: other, object: announce_activity)

        it "marks the announce activity as undone" do
          expect { InboxActivityProcessor.process(account, undo_activity) }
            .to change { announce_activity.reload!.undone_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, undo_activity, receive_task_class: MockReceiveTask)
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
          expect { InboxActivityProcessor.process(account, delete_activity) }
            .to change { object_to_delete.reload!.deleted_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, delete_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(delete_activity)
        end
      end

      context "given an Actor" do
        let_create(:delete, named: :delete_activity, actor: other, object: other)

        it "marks the actor as deleted" do
          expect { InboxActivityProcessor.process(account, delete_activity) }
            .to change { other.reload!.deleted_at }.from(nil)
        end

        it "schedules receive task" do
          InboxActivityProcessor.process(account, delete_activity, receive_task_class: MockReceiveTask)
          expect(MockReceiveTask.schedule_called_count).to eq(1)
          expect(MockReceiveTask.last_receiver).to eq(account.actor)
          expect(MockReceiveTask.last_activity).to eq(delete_activity)
        end
      end
    end

    context "with Create activity" do
      let_create(:create, named: :create_activity, actor: other, object: object)

      it "schedules receive task" do
        InboxActivityProcessor.process(account, create_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(create_activity)
      end
    end

    context "with Announce activity" do
      let_create(:announce, named: :announce_activity, actor: other, object: object)

      it "schedules receive task" do
        InboxActivityProcessor.process(account, announce_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(announce_activity)
      end
    end

    context "with a QuoteRequest activity" do
      let_create(:note, attributed_to: account.actor)
      let_create(:quote_request, named: :quote_request_activity, actor: other, object: note, instrument_iri: "https://remote/objects/123")

      it "creates a quote authorization" do
        expect { InboxActivityProcessor.process(account, quote_request_activity) }
          .to change { ActivityPub::Object::QuoteAuthorization.count }.by(1)
      end

      it "creates a quote decision" do
        expect { InboxActivityProcessor.process(account, quote_request_activity) }
          .to change { QuoteDecision.count }.by(1)
        decision = QuoteDecision.where(interaction_target_iri: note.iri, interacting_object_iri: "https://remote/objects/123").first
        expect(decision.decision).to eq("accept")
      end

      it "creates an accept activity with a quote authorization" do
        expect { InboxActivityProcessor.process(account, quote_request_activity) }
          .to change { ActivityPub::Activity::Accept.count }.by(1)
        accept = ActivityPub::Activity::Accept.all.last
        expect(accept.actor).to eq(account.actor)
        expect(accept.object).to eq(quote_request_activity)
        expect(accept.result).to be_a(ActivityPub::Object::QuoteAuthorization)
      end

      it "schedules receive task" do
        InboxActivityProcessor.process(account, quote_request_activity, receive_task_class: MockReceiveTask)
        expect(MockReceiveTask.schedule_called_count).to eq(1)
        expect(MockReceiveTask.last_receiver).to eq(account.actor)
        expect(MockReceiveTask.last_activity).to eq(quote_request_activity)
      end

      it "schedules deliver task" do
        InboxActivityProcessor.process(account, quote_request_activity, deliver_task_class: MockDeliverTask)
        expect(MockDeliverTask.schedule_called_count).to eq(1)
        expect(MockDeliverTask.last_sender).to eq(account.actor)
        expect(MockDeliverTask.last_activity).to be_a(ActivityPub::Activity::Accept)
      end

      context "given an existing quote decision" do
        let_create!(:quote_authorization, attributed_to: account.actor)
        let_create!(:quote_decision, quote_authorization: quote_authorization, interaction_target_iri: note.iri, interacting_object_iri: "https://remote/objects/123", decision: "accept")

        it "reuses the existing quote authorization" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .not_to change { ActivityPub::Object::QuoteAuthorization.count }
        end

        it "creates a new accept activity" do
          expect { InboxActivityProcessor.process(account, quote_request_activity) }
            .to change { ActivityPub::Activity::Accept.count }.by(1)
          accept = ActivityPub::Activity::Accept.all.last
          expect(accept.result).to eq(quote_authorization)
        end
      end
    end
  end
end
