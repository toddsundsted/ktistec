require "../../../src/models/task/distribute_poll_updates"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::DistributePollUpdates do
  setup_spec

  let(actor) { register.actor }
  let_create(:actor, named: :voter1)
  let_create(:actor, named: :voter2)
  let_create(:actor, named: :voter3)
  let_build(
    :question,
    attributed_to: actor,
    to: ["https://www.w3.org/ns/activitystreams#Public"],
    cc: [actor.followers.not_nil!],
    published: Time.utc,
  )
  let_create!(
    :poll,
    question: question,
    options: [
      Poll::Option.new("Option A", 0),
      Poll::Option.new("Option B", 0),
    ],
    voters_count: 0,
    closed_at: 1.hour.from_now,
  )

  describe "#perform" do
    let_build(:distribute_poll_updates_task, actor: actor, question: question)

    macro vote(index, voter, name)
      let_create!(
        :note, named: vote{{index}},
        name: {{name}},
        in_reply_to: question,
        attributed_to: {{voter}},
        special: "vote",
      )
    end

    context "given a remote question" do
      let_create!(:question) # remote by default

      it "does not create `Update`" do
        expect { distribute_poll_updates_task.perform }.not_to change { ActivityPub::Activity::Update.count }
      end

      it "does not reschedule itself" do
        distribute_poll_updates_task.perform
        expect(distribute_poll_updates_task.next_attempt_at).to be_nil
      end
    end

    context "given a local question" do
      it "does not create `Update`" do
        expect { distribute_poll_updates_task.perform }.not_to change { ActivityPub::Activity::Update.count }
      end

      it "reschedules itself" do
        distribute_poll_updates_task.perform
        expect(distribute_poll_updates_task.next_attempt_at).not_to be_nil
      end

      context "with votes" do
        vote(1, voter1, "Option A")
        vote(2, voter2, "Option B")
        vote(3, voter3, "Option A")

        it "calculates vote tallies" do
          distribute_poll_updates_task.perform
          option_a = poll.options.find! { |o| o.name == "Option A" }
          option_b = poll.options.find! { |o| o.name == "Option B" }
          expect(option_a.votes_count).to eq(2)
          expect(option_b.votes_count).to eq(1)
        end

        it "updates voters_count" do
          distribute_poll_updates_task.perform
          expect(poll.voters_count).to eq(3)
        end

        it "updates `updated_at`" do
          expect { sleep 0.01.seconds; distribute_poll_updates_task.perform }.to change { question.reload!.updated_at }
        end

        it "creates `Update`" do
          expect { distribute_poll_updates_task.perform }.to change { ActivityPub::Activity::Update.count }.by(1)
        end

        it "update includes original audience in `to`" do
          distribute_poll_updates_task.perform
          update = ActivityPub::Activity::Update.all.last
          expect(update.to).to contain("https://www.w3.org/ns/activitystreams#Public")
        end

        it "update includes voters in `to`" do
          distribute_poll_updates_task.perform
          update = ActivityPub::Activity::Update.all.last
          expect(update.to).to contain(voter1.iri, voter2.iri, voter3.iri)
        end

        it "update includes original `cc`" do
          distribute_poll_updates_task.perform
          update = ActivityPub::Activity::Update.all.last
          expect(update.cc).to eq([actor.followers])
        end

        it "reschedules itself" do
          distribute_poll_updates_task.perform
          expect(distribute_poll_updates_task.next_attempt_at).not_to be_nil
        end
      end
    end

    context "when running again without new votes" do
      vote(1, voter1, "Option A")

      pre_condition do
        distribute_poll_updates_task.perform
        expect(ActivityPub::Activity::Update.count).to eq(1)
      end

      it "does not create another `Update`" do
        expect { distribute_poll_updates_task.perform }.not_to change { ActivityPub::Activity::Update.count }
      end

      it "reschedules itself" do
        distribute_poll_updates_task.perform
        expect(distribute_poll_updates_task.next_attempt_at).not_to be_nil
      end
    end

    context "when poll has expired" do
      vote(1, voter1, "Option A")

      before_each { poll.assign(closed_at: 1.minute.ago).save(skip_validation: true) }

      it "creates final `Update`" do
        expect { distribute_poll_updates_task.perform }.to change { ActivityPub::Activity::Update.count }.by(1)
      end

      it "does not reschedule itself" do
        distribute_poll_updates_task.perform
        expect(distribute_poll_updates_task.next_attempt_at).to be_nil
      end
    end

    context "when voter votes multiple times" do
      vote(1, voter1, "Option A")
      vote(2, voter1, "Option B")

      it "tallies both votes" do
        distribute_poll_updates_task.perform
        option_a = poll.options.find! { |o| o.name == "Option A" }
        option_b = poll.options.find! { |o| o.name == "Option B" }
        expect(option_a.votes_count).to eq(1)
        expect(option_b.votes_count).to eq(1)
      end

      it "updates voters_count" do
        distribute_poll_updates_task.perform
        expect(poll.voters_count).to eq(1)
      end
    end

    context "when recipients overlap" do
      let_create!(
        :question,
        attributed_to: actor,
        to: [voter1.iri, "https://www.w3.org/ns/activitystreams#Public"],
        cc: [] of String,
      )
      vote(1, voter1, "Option A")
      vote(2, voter2, "Option B")

      it "deduplicates recipients" do
        distribute_poll_updates_task.perform
        update = ActivityPub::Activity::Update.all.last
        expect(update.to.not_nil!.count(voter1.iri)).to eq(1)
        expect(update.to.not_nil!.count(voter2.iri)).to eq(1)
      end
    end
  end

  describe "#path_to" do
    let_build(:distribute_poll_updates_task, question: question)

    it "returns path to the question" do
      expect(distribute_poll_updates_task.path_to).to eq("/remote/objects/#{question.id}")
    end
  end
end
