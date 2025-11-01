require "../../../src/models/task/handle_follow_request"
require "../../../src/models/activity_pub/activity/follow"
require "../../../src/models/activity_pub/activity/accept"
require "../../../src/services/outbox_activity_processor"
require "../../../src/models/relationship/social/follow"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::HandleFollowRequest do
  setup_spec

  let(account) { register }
  let_create(:actor, named: :other)
  let_create!(:follow, named: :follow_activity, actor: other, object: account.actor)

  describe "#perform" do
    let_build(:handle_follow_request_task, recipient: account.actor, activity: follow_activity)

    it "does not create an Accept activity" do
      expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Accept.count }
    end

    it "does not create a Follow activity" do
      expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
    end

    context "when the account has auto_approve_followers enabled" do
      before_each do
        account.assign(auto_approve_followers: true).save
      end

      it "creates and processes Accept activity" do
        expect { handle_follow_request_task.perform }.to change { ActivityPub::Activity::Accept.count }.by(1)

        accept_activity = ActivityPub::Activity::Accept.find(actor: account.actor, object: follow_activity)
        expect(accept_activity.actor).to eq(account.actor)
        expect(accept_activity.object).to eq(follow_activity)
        expect(accept_activity.to).to eq([other.iri])
      end

      it "schedules delivery of Accept activity" do
        handle_follow_request_task.perform

        accept_activity = ActivityPub::Activity::Accept.find(actor: account.actor, object: follow_activity)
        expect(Task::Deliver.find?(sender: account.actor, activity: accept_activity)).not_to be_nil
      end

      context "given an existing follow relationship" do
        let_create!(:follow_relationship, actor: other, object: account.actor, confirmed: false)

        it "confirms the follow relationship" do
          expect { handle_follow_request_task.perform }.to change { follow_relationship.reload!.confirmed }.from(false).to(true)
        end
      end
    end

    context "when the account has auto_follow_back enabled" do
      before_each do
        account.assign(auto_follow_back: true).save
      end

      it "creates and processes Follow activity" do
        expect { handle_follow_request_task.perform }.to change { ActivityPub::Activity::Follow.count }.by(1)

        follow_activity_back = ActivityPub::Activity::Follow.find(actor: account.actor, object: other)
        expect(follow_activity_back.actor).to eq(account.actor)
        expect(follow_activity_back.object).to eq(other)
        expect(follow_activity_back.to).to eq([other.iri])
      end

      it "schedules delivery of Follow activity" do
        handle_follow_request_task.perform

        follow_activity_back = ActivityPub::Activity::Follow.find(actor: account.actor, object: other)
        expect(Task::Deliver.find?(sender: account.actor, activity: follow_activity_back)).not_to be_nil
      end

      context "given an existing follow relationship" do
        let_create!(:follow_relationship, named: nil, actor: account.actor, object: other, visible: false)

        it "does not create a Follow activity" do
          expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
        end
      end

      context "given an existing follow activity" do
        let_create!(:follow, named: nil, actor: account.actor, object: other)

        it "does not create a Follow activity" do
          expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
        end
      end
    end

    context "with activity is missing" do
      before_each do
        account.assign(auto_approve_followers: true, auto_follow_back: true).save
      end

      let_build(:handle_follow_request_task, recipient: account.actor, subject_iri: "https://invalid/activity")

      it "completes gracefully without error" do
        expect { handle_follow_request_task.perform }.not_to raise_error
      end

      it "does not create an Accept activity" do
        expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Accept.count }
      end

      it "does not create a Follow activity" do
        expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
      end
    end

    context "when account is missing" do
      before_each do
        account.assign(auto_approve_followers: true, auto_follow_back: true).save
      end

      let_build(:handle_follow_request_task, source_iri: "https://invalid/actor", activity: follow_activity)

      it "completes gracefully without error" do
        expect { handle_follow_request_task.perform }.not_to raise_error
      end

      it "does not create an Accept activity" do
        expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Accept.count }
      end

      it "does not create a Follow activity" do
        expect { handle_follow_request_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
      end
    end
  end
end
