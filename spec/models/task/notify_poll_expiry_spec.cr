require "../../../src/models/task/notify_poll_expiry"
require "../../../src/models/activity_pub/object/question"
require "../../../src/models/relationship/content/notification/poll/expiry"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::NotifyPollExpiry do
  setup_spec

  let_create!(:question)
  let_create(:actor, named: :voter1)
  let_create(:actor, named: :voter2)

  alias Expiry = Relationship::Content::Notification::Poll::Expiry

  describe "#perform" do
    let_build(:notify_poll_expiry_task, question: question)

    context "with no voters" do
      it "does not create any notifications" do
        expect { notify_poll_expiry_task.perform }.not_to change { Expiry.count }
      end
    end

    macro vote(index, actor, name)
      let_create!(
        :note,
        named: vote{{index}},
        name: {{name}},
        in_reply_to: question,
        attributed_to: {{actor}},
        content: nil,
        special: "vote",
      )
    end

    context "with one voter" do
      vote(1, voter1, "Option A")

      it "creates one notification" do
        expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(1)
      end

      it "creates notification for the first voter" do
        notify_poll_expiry_task.perform
        notification = Expiry.find(owner: voter1, question: question)
        expect(notification.owner).to eq(voter1)
      end

      context "and another voter" do
        vote(2, voter2, "Option B")

        it "creates two notifications" do
          expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(2)
        end

        it "creates notification for the second voter" do
          notify_poll_expiry_task.perform
          notification = Expiry.find(owner: voter2, question: question)
          expect(notification.owner).to eq(voter2)
        end
      end
    end

    context "with one voter voting multiple times" do
      vote(1, voter1, "Option A")
      vote(2, voter1, "Option B")

      it "creates only one notification" do
        expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(1)
      end
    end

    context "if task runs multiple times" do
      vote(1, voter1, "Option A")

      pre_condition { expect { notify_poll_expiry_task.perform }.to change { Expiry.count } }

      it "does not create duplicate notifications" do
        expect { notify_poll_expiry_task.perform }.not_to change { Expiry.count }
      end
    end

    context "when question is missing" do
      vote(1, voter1, "Option A")
      vote(2, voter2, "Option B")

      before_each do
        notify_poll_expiry_task.save.question.destroy
        notify_poll_expiry_task.reload!
      end

      it "runs without error" do
        expect { notify_poll_expiry_task.perform }.not_to raise_error
      end

      it "does not create any notifications" do
        expect { notify_poll_expiry_task.perform }.not_to change { Expiry.count }
      end
    end
  end
end
