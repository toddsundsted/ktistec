require "../../src/models/poll"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Poll do
  setup_spec

  describe "validation" do
    context "when question is nil" do
      let(poll) { Poll.new }

      it "must be present" do
        expect(poll.valid?).to be_false
        expect(poll.errors.keys).to contain("question")
        expect(poll.errors["question"]?).to contain("must be present")
      end
    end

    context "when options is empty" do
      let_build(:poll, options: [] of Poll::Option)

      it "can't be empty" do
        expect(poll.valid?).to be_false
        expect(poll.errors.keys).to contain("options")
        expect(poll.errors["options"]?).to contain("can't be empty")
      end
    end

    context "when options has one option" do
      let_build(:poll, options: [Poll::Option.new("yes")])

      it "must contain at least 2 options" do
        expect(poll.valid?).to be_false
        expect(poll.errors.keys).to contain("options")
        expect(poll.errors["options"]?).to contain("must contain at least 2 options")
      end
    end

    context "multiple_choice is not specified" do
      let_build(:poll)

      it "defaults to false" do
        expect(poll.multiple_choice).to be_false
      end
    end
  end

  describe "before_save" do
    context "when question is draft and saved" do
      let_build(:poll, closed_at: Time.unix(86400))
      let_build(:question, poll: poll, local: true, published: nil)

      post_condition { expect(question.draft?).to be_true }

      it "does not change `closed_at`" do
        question.save
        expect(poll.closed_at).to eq(Time.unix(86400))
      end
    end

    context "when question is saved and becomes published" do
      let_build(:poll, closed_at: Time.unix(86400))
      let_build(:question, poll: poll, local: true, published: nil)

      post_condition { expect(question.draft?).to be_false }

      it "changes `closed_at`" do
        question.assign(published: Time.utc).save
        expect(poll.closed_at).to be_close(Time.utc + 86400.seconds, 2.seconds)
      end
    end

    context "when question is published and is saved again" do
      let_build(:poll, closed_at: Time.unix(86400))
      let_create!(:question, poll: poll, local: true, published: 1.day.ago)

      pre_condition { expect(question.draft?).to be_false }

      it "does not change `closed_at`" do
        expect { poll.assign(voters_count: 10).save }.not_to change { poll.closed_at }
      end
    end
  end

  describe "#options" do
    let_build(:poll)

    it "stores and retrieves option data" do
      poll.options = [
        Poll::Option.new("Yes", 10),
        Poll::Option.new("No", 5),
      ]
      expect(poll.options.size).to eq(2)
      expect(poll.options[0].name).to eq("Yes")
      expect(poll.options[0].votes_count).to eq(10)
      expect(poll.options[1].name).to eq("No")
      expect(poll.options[1].votes_count).to eq(5)
    end
  end

  describe "#expired?" do
    let_build(:poll, named: :open_poll, closed_at: nil)
    let_build(:poll, named: :future_poll, closed_at: Time.utc + 1.hour)
    let_build(:poll, named: :past_poll, closed_at: Time.utc - 1.hour)

    it "returns false when closed_at is nil" do
      expect(open_poll.expired?).to be_false
    end

    it "returns false when closed_at is in the future" do
      expect(future_poll.expired?).to be_false
    end

    it "returns true when closed_at is in the past" do
      expect(past_poll.expired?).to be_true
    end

    context "when poll is a draft" do
      let_build(:question, poll: past_poll, local: true, published: nil)

      pre_condition { expect(question.draft?).to be_true }

      it "returns false even though closed is in the past" do
        expect(past_poll.expired?).to be_false
      end
    end
  end

  describe "#adjust_votes" do
    let_create!(
      :poll,
      options: [
        Poll::Option.new("Yes", 10),
        Poll::Option.new("No", 5),
      ],
      voters_count: 15
    )

    let(question) { poll.question }

    let_create(:actor, local: true)

    let(vote_times) { question.votes_by(actor).map(&.created_at) }

    it "returns vote counts" do
      result = poll.adjust_votes(question, actor)

      expect(result[:options][0].votes_count).to eq(10)
      expect(result[:options][1].votes_count).to eq(5)
      expect(result[:voters_count]).to eq(15)
    end

    macro vote(name)
      let_create!(
        :note, named: nil,
        name: {{name}},
        in_reply_to: question,
        attributed_to: actor,
        special: "vote",
      )
    end

    context "votes are older than question" do
      vote("Yes")

      before_each do
        question.assign(updated_at: vote_times.max + 1.minute) # don't save
      end

      it "does not adjust counts" do
        result = poll.adjust_votes(question, actor)

        expect(result[:options][0].votes_count).to eq(10)
        expect(result[:options][1].votes_count).to eq(5)
        expect(result[:voters_count]).to eq(15)
      end
    end

    context "votes are newer than question_at" do
      context "with single recent vote" do
        vote("Yes")

        before_each do
          question.assign(updated_at: vote_times.min - 1.minute) # don't save
        end

        it "adjusts counts" do
          result = poll.adjust_votes(question, actor)

          expect(result[:options][0].votes_count).to eq(11)
          expect(result[:options][1].votes_count).to eq(5)
          expect(result[:voters_count]).to eq(16)
        end
      end

      context "with multiple recent votes" do
        vote("Yes")
        vote("No")

        before_each do
          question.assign(updated_at: vote_times.min - 1.minute) # don't save
        end

        it "adjusts counts" do
          result = poll.adjust_votes(question, actor)

          expect(result[:options][0].votes_count).to eq(11)
          expect(result[:options][1].votes_count).to eq(6)
          expect(result[:voters_count]).to eq(16)
        end
      end

      context "with multiple recent votes for same option" do
        vote("Yes")
        vote("Yes")

        before_each do
          question.assign(updated_at: vote_times.min - 1.minute) # don't save
        end

        it "adjusts counts" do
          result = poll.adjust_votes(question, actor)

          expect(result[:options][0].votes_count).to eq(12)
          expect(result[:options][1].votes_count).to eq(5)
          expect(result[:voters_count]).to eq(16)
        end
      end
    end
  end
end
