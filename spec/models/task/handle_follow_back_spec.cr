require "../../../src/models/task/handle_follow_back"
require "../../../src/models/activity_pub/activity/follow"
require "../../../src/services/outbox_activity_processor"
require "../../../src/models/relationship/social/follow"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::HandleFollowBack do
  setup_spec

  let(account) { register }
  let_create(:actor, named: :other)
  let_create!(:follow, named: :follow_activity, actor: other, object: account.actor)

  describe "#perform" do
    let_build(:handle_follow_back_task, recipient: account.actor, activity: follow_activity)

    it "does not create a Follow activity" do
      expect { handle_follow_back_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
    end

    context "when the account has auto_follow_back enabled" do
      before_each do
        account.assign(auto_follow_back: true).save
      end

      it "creates and processes Follow activity" do
        expect { handle_follow_back_task.perform }.to change { ActivityPub::Activity::Follow.count }.by(1)

        follow_activity_back = ActivityPub::Activity::Follow.find(actor: account.actor, object: other)
        expect(follow_activity_back.actor).to eq(account.actor)
        expect(follow_activity_back.object).to eq(other)
        expect(follow_activity_back.to).to eq([other.iri])
      end

      it "schedules delivery of Follow activity" do
        handle_follow_back_task.perform

        follow_activity_back = ActivityPub::Activity::Follow.find(actor: account.actor, object: other)
        expect(Task::Deliver.find?(sender: account.actor, activity: follow_activity_back)).not_to be_nil
      end

      context "given an existing follow relationship" do
        let_create!(:follow_relationship, named: nil, actor: account.actor, object: other, visible: false)

        it "does not create a Follow activity" do
          expect { handle_follow_back_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
        end
      end

      context "given an existing follow activity" do
        let_create!(:follow, named: nil, actor: account.actor, object: other)

        it "does not create a Follow activity" do
          expect { handle_follow_back_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
        end
      end
    end

    context "with activity is missing" do
      before_each do
        account.assign(auto_follow_back: true).save
      end

      let_build(:handle_follow_back_task, recipient: account.actor, subject_iri: "https://invalid/activity")

      it "completes gracefully without error" do
        expect { handle_follow_back_task.perform }.not_to raise_error
      end

      it "does not create a Follow activity" do
        expect { handle_follow_back_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
      end
    end

    context "when account is missing" do
      before_each do
        account.assign(auto_follow_back: true).save
      end

      let_build(:handle_follow_back_task, source_iri: "https://invalid/actor", activity: follow_activity)

      it "completes gracefully without error" do
        expect { handle_follow_back_task.perform }.not_to raise_error
      end

      it "does not create a Follow activity" do
        expect { handle_follow_back_task.perform }.not_to change { ActivityPub::Activity::Follow.count }
      end
    end
  end
end
