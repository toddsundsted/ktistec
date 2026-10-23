require "../../src/serializers/stats"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Serializers::Stats do
  setup_spec

  describe Serializers::Stats::Quartiles do
    describe ".from" do
      it "computes the first quartile" do
        expect(described_class.from([1.0, 2.0, 3.0, 4.0, 5.0]).q1).to eq(2.0)
      end

      it "computes the median" do
        expect(described_class.from([1.0, 2.0, 3.0, 4.0, 5.0]).median).to eq(3.0)
      end

      it "computes the third quartile" do
        expect(described_class.from([1.0, 2.0, 3.0, 4.0, 5.0]).q3).to eq(4.0)
      end

      it "interpolates linearly between values" do
        expect(described_class.from([1.0, 2.0]).q1).to eq(1.25)
      end

      it "does not depend on the order of the values" do
        expect(described_class.from([5.0, 1.0, 4.0, 2.0, 3.0])).to eq(described_class.from([1.0, 2.0, 3.0, 4.0, 5.0]))
      end

      it "returns no quartiles given no values" do
        expect(described_class.from([] of Float64).median).to be_nil
      end
    end
  end

  describe ".from" do
    let(now) { Time.utc(2026, 10, 22) }

    let_create(:actor, named: :owner)

    subject { described_class.from(owner.iri, now) }

    describe "#posting_rate" do
      let_create(:actor, named: :author)
      let_create!(:object, attributed_to: author, published: now - 89.days)

      context "given the owner follows the author" do
        let_create!(:follow_relationship, actor: owner, object: author, confirmed: true)

        it "has the author's rate over 90 days as its median" do
          expect(subject.posting_rate.median).to eq(1.0 / 90)
        end

        context "and another followed author who hasn't posted" do
          let_create(:actor, named: :other)
          let_create!(:follow_relationship, named: nil, actor: owner, object: other, confirmed: true)

          it "omits that author from the median" do
            expect(subject.posting_rate.median).to eq(1.0 / 90)
          end
        end

        context "and a post by an author the owner doesn't follow" do
          let_create(:actor, named: :other)
          let_create!(:object, named: nil, attributed_to: other, published: now - 89.days)

          it "omits that post from the median" do
            expect(subject.posting_rate.median).to eq(1.0 / 90)
          end
        end

        context "but the post is more than 90 days old" do
          before_each { object.assign(published: now - 91.days).save }

          it "does not count the post" do
            expect(subject.posting_rate.median).to be_nil
          end
        end

        context "but the post is deleted" do
          before_each { object.delete! }

          it "does not count the post" do
            expect(subject.posting_rate.median).to be_nil
          end
        end

        context "but the post is blocked" do
          before_each { object.block! }

          it "does not count the post" do
            expect(subject.posting_rate.median).to be_nil
          end
        end

        context "but the post is special" do
          before_each { object.assign(special: "vote").save }

          it "does not count the post" do
            expect(subject.posting_rate.median).to be_nil
          end
        end

        context "but the follow is unconfirmed" do
          before_each { follow_relationship.assign(confirmed: false).save }

          it "does not count the author" do
            expect(subject.posting_rate.median).to be_nil
          end
        end

        context "but the author is deleted" do
          before_each { author.delete! }

          it "does not count the author" do
            expect(subject.posting_rate.median).to be_nil
          end
        end

        context "but the author is blocked" do
          before_each { author.block! }

          it "does not count the author" do
            expect(subject.posting_rate.median).to be_nil
          end
        end
      end

      context "given the owner follows mentions of the author" do
        let_create!(:follow_mention_relationship, actor: owner, href: author.iri, confirmed: true)

        it "does not count the author" do
          expect(subject.posting_rate.median).to be_nil
        end
      end

      context "given another actor follows the author" do
        let_create(:actor, named: :other)
        let_create!(:follow_relationship, actor: other, object: author, confirmed: true)

        it "does not count the author" do
          expect(subject.posting_rate.median).to be_nil
        end
      end
    end
  end
end
