require "../../../src/models/task/notify_poll_expiry"
require "../../../src/models/activity_pub/object/question"
require "../../../src/models/relationship/content/notification/poll/expiry"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::NotifyPollExpiry do
  setup_spec

  let_create!(:question)
  let_create!(:poll, question: question, closed_at: 1.minute.ago)
  let_create(:actor, named: :voter1)
  let_create(:actor, named: :voter2)

  alias Expiry = Relationship::Content::Notification::Poll::Expiry

  describe "#perform" do
    let_build(:notify_poll_expiry_task, question: question)

    context "with no voters" do
      it "creates notification for the poll author" do
        expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(1)
      end

      it "creates notification for the author" do
        notify_poll_expiry_task.perform
        expect(Expiry.find?(owner: question.attributed_to, question: question)).not_to be_nil
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

      it "creates two notifications" do
        expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(2)
      end

      it "creates notification for the first voter" do
        notify_poll_expiry_task.perform
        expect(Expiry.find?(owner: voter1, question: question)).not_to be_nil
      end

      it "creates notification for the author" do
        notify_poll_expiry_task.perform
        expect(Expiry.find?(owner: question.attributed_to, question: question)).not_to be_nil
      end

      context "and another voter" do
        vote(2, voter2, "Option B")

        it "creates three notifications" do
          expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(3)
        end

        it "creates notification for the second voter" do
          notify_poll_expiry_task.perform
          expect(Expiry.find?(owner: voter2, question: question)).not_to be_nil
        end
      end
    end

    context "with one voter voting multiple times" do
      vote(1, voter1, "Option A")
      vote(2, voter1, "Option B")

      it "creates two notifications" do
        expect { notify_poll_expiry_task.perform }.to change { Expiry.count }.by(2)
      end

      it "creates one notification for the voter" do
        notify_poll_expiry_task.perform
        notifications = Expiry.where(owner: voter1, question: question)
        expect(notifications.size).to eq(1)
      end

      it "creates one notification for the author" do
        notify_poll_expiry_task.perform
        notifications = Expiry.where(owner: question.attributed_to, question: question)
        expect(notifications.size).to eq(1)
      end
    end

    context "if task runs multiple times" do
      vote(1, voter1, "Option A")

      pre_condition { expect { notify_poll_expiry_task.perform }.to change { Expiry.count } }

      it "does not create duplicate notifications" do
        expect { notify_poll_expiry_task.perform }.not_to change { Expiry.count }
      end
    end

    context "when poll closed_at has changed" do
      let(future_time) { 1.hour.from_now }
      let_create!(:poll, question: question, closed_at: future_time)
      vote(1, voter1, "Option A")

      it "does not create notifications" do
        expect { notify_poll_expiry_task.perform }.not_to change { Expiry.count }
      end

      it "reschedules task for new expiry time" do
        notify_poll_expiry_task.perform
        expect(notify_poll_expiry_task.next_attempt_at).to be_close(future_time, 1.second)
      end
    end

    context "when poll has expired" do
      let_create!(:poll, question: question, closed_at: 1.hour.ago)
      vote(1, voter1, "Option A")

      it "does not reschedule task" do
        notify_poll_expiry_task.perform
        expect(notify_poll_expiry_task.next_attempt_at).to be_nil
      end
    end

    context "when poll has no closed_at" do
      let_create!(:poll, question: question, closed_at: nil)
      vote(1, voter1, "Option A")

      it "does not reschedule task" do
        notify_poll_expiry_task.perform
        expect(notify_poll_expiry_task.next_attempt_at).to be_nil
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
