require "../../../src/models/feed/question"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Question do
  setup_spec

  let(now) { Time.utc }

  describe ".pull" do
    it "pulls nothing" do
      expect(described_class.pull).to be_nil
    end

    context "given a question" do
      let_create!(:feed_question, due_at: now - 1.minute)

      it "pulls the question" do
        expect(described_class.pull.try(&.id)).to eq(feed_question.id)
      end

      it "marks the question as in a batch" do
        described_class.pull
        expect(described_class.find(feed_question.id).batched).to be_true
      end

      it "pulls the question once" do
        described_class.pull
        expect(described_class.pull).to be_nil
      end

      context "that is not due" do
        before_each { feed_question.assign(due_at: now + 1.minute).save }

        it "pulls nothing" do
          expect(described_class.pull).to be_nil
        end
      end

      context "and an earlier question" do
        let_create!(:feed_question, named: earlier, due_at: now - 1.hour)

        it "pulls the earlier question" do
          expect(described_class.pull.try(&.id)).to eq(earlier.id)
        end

        context "when the later question is live" do
          before_each { feed_question.assign(live: true).save }

          it "pulls the live question" do
            expect(described_class.pull.try(&.id)).to eq(feed_question.id)
          end
        end
      end
    end
  end
end
