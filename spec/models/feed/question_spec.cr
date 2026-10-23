require "../../../src/models/feed/question"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Question do
  setup_spec

  let(now) { Time.utc }

  let_create(:feed_version, named: version)

  describe ".next_version_id" do
    it "returns nil, given no questions" do
      expect(described_class.next_version_id).to be_nil
    end

    context "given a question" do
      let_create!(:feed_question, version: version, due_at: now - 1.minute)

      it "returns its version once it is due" do
        expect(described_class.next_version_id).to eq(version.id)
      end

      context "that is not yet due" do
        before_each { feed_question.assign(due_at: now + 1.minute).save }

        it "returns nil" do
          expect(described_class.next_version_id).to be_nil
        end
      end

      context "that is in a batch" do
        before_each { feed_question.assign(batched: true).save }

        it "returns nil" do
          expect(described_class.next_version_id).to be_nil
        end
      end

      context "and an earlier question" do
        let_create(:feed_version, named: other)
        let_create!(:feed_question, named: earlier, version: other, due_at: now - 1.hour)

        it "returns the earlier question's version" do
          expect(described_class.next_version_id).to eq(other.id)
        end

        context "whose judge is excluded" do
          let_create(:feed_version, named: other, backend: "other")

          it "returns the later question's version" do
            expect(described_class.next_version_id(excluding: ["other"])).to eq(version.id)
          end
        end

        context "but the later question is live" do
          before_each { feed_question.assign(live: true).save }

          it "returns the later question's version" do
            expect(described_class.next_version_id).to eq(version.id)
          end
        end
      end
    end
  end

  describe ".pull" do
    it "pulls nothing, given no questions" do
      expect(described_class.pull(version.id!, 2)).to be_empty
    end

    context "given questions on the version" do
      let_create!(:feed_question, named: later, version: version, due_at: now - 1.minute)
      let_create!(:feed_question, named: earlier, version: version, due_at: now - 1.hour)

      it "pulls them" do
        expect(described_class.pull(version.id!, 2).map(&.id)).to contain_exactly(earlier.id, later.id).in_any_order
      end

      it "marks them as in a batch" do
        described_class.pull(version.id!, 2)
        expect(described_class.where(batched: true).map(&.id)).to contain_exactly(earlier.id, later.id).in_any_order
      end

      it "pulls them once" do
        described_class.pull(version.id!, 2)
        expect(described_class.pull(version.id!, 2)).to be_empty
      end

      context "and a limit of one" do
        it "pulls the earlier question" do
          expect(described_class.pull(version.id!, 1).map(&.id)).to eq([earlier.id])
        end

        context "but the later question is live" do
          before_each { later.assign(live: true).save }

          it "pulls the later question" do
            expect(described_class.pull(version.id!, 1).map(&.id)).to eq([later.id])
          end
        end
      end

      context "and the later question is not due" do
        before_each { later.assign(due_at: now + 1.minute).save }

        it "pulls the earlier question" do
          expect(described_class.pull(version.id!, 2).map(&.id)).to eq([earlier.id])
        end
      end
    end

    context "given a question on another version" do
      let_create!(:feed_question, due_at: now - 1.minute)

      it "pulls nothing" do
        expect(described_class.pull(version.id!, 2)).to be_empty
      end
    end
  end
end
