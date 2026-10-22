require "../../src/serializers/author"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Serializers::Author do
  setup_spec

  describe ".from" do
    let(now) { Time.utc(2026, 10, 22) }

    let_create(:actor, named: :owner)
    let_create(:actor, named: :author)

    subject { described_class.from(author.iri, owner.iri, now) }

    it "carries the author's IRI" do
      expect(subject.iri).to eq(author.iri)
    end

    describe "#followed" do
      context "given the owner follows the author" do
        let_create!(:follow_relationship, actor: owner, object: author, confirmed: true)

        it "is true" do
          expect(subject.followed).to be_true
        end

        context "but the follow is unconfirmed" do
          before_each { follow_relationship.assign(confirmed: false).save }

          it "is false" do
            expect(subject.followed).to be_false
          end
        end

        context "but the author is deleted" do
          before_each { author.delete! }

          it "is false" do
            expect(subject.followed).to be_false
          end
        end

        context "but the author is blocked" do
          before_each { author.block! }

          it "is false" do
            expect(subject.followed).to be_false
          end
        end
      end

      context "given the owner follows mentions of the author" do
        let_create!(:follow_mention_relationship, actor: owner, href: author.iri, confirmed: true)

        it "is false" do
          expect(subject.followed).to be_false
        end
      end

      context "given another actor follows the author" do
        let_create(:actor, named: :other)
        let_create!(:follow_relationship, actor: other, object: author, confirmed: true)

        it "is false" do
          expect(subject.followed).to be_false
        end
      end

      context "given the owner follows another actor" do
        let_create(:actor, named: :other)
        let_create!(:follow_relationship, actor: owner, object: other, confirmed: true)

        it "is false" do
          expect(subject.followed).to be_false
        end
      end
    end

    describe "#rate_7" do
      it "is zero given no posts" do
        expect(subject.rate_7).to eq(0.0)
      end

      context "given a post 6 days ago" do
        let_create!(:object, attributed_to: author, published: now - 6.days)

        it "is one post per 7 days" do
          expect(subject.rate_7).to eq(1.0 / 7)
        end
      end

      context "given a post 8 days ago" do
        let_create!(:object, attributed_to: author, published: now - 8.days)

        it "does not count the post" do
          expect(subject.rate_7).to eq(0.0)
        end
      end
    end

    describe "#rate_30" do
      it "is zero given no posts" do
        expect(subject.rate_30).to eq(0.0)
      end

      context "given a post 29 days ago" do
        let_create!(:object, attributed_to: author, published: now - 29.days)

        it "is one post per 30 days" do
          expect(subject.rate_30).to eq(1.0 / 30)
        end
      end

      context "given a post 31 days ago" do
        let_create!(:object, attributed_to: author, published: now - 31.days)

        it "does not count the post" do
          expect(subject.rate_30).to eq(0.0)
        end
      end
    end

    describe "#rate_90" do
      context "given a post 89 days ago" do
        let_create!(:object, attributed_to: author, published: now - 89.days)

        it "is one post per 90 days" do
          expect(subject.rate_90).to eq(1.0 / 90)
        end

        context "that is deleted" do
          before_each { object.delete! }

          it "does not count the post" do
            expect(subject.rate_90).to eq(0.0)
          end
        end

        context "that is blocked" do
          before_each { object.block! }

          it "does not count the post" do
            expect(subject.rate_90).to eq(0.0)
          end
        end

        context "that is special" do
          before_each { object.assign(special: "vote").save }

          it "does not count the post" do
            expect(subject.rate_90).to eq(0.0)
          end
        end

        context "and the author is deleted" do
          before_each { author.delete! }

          it "does not count the post" do
            expect(subject.rate_90).to eq(0.0)
          end
        end

        context "and the author is blocked" do
          before_each { author.block! }

          it "does not count the post" do
            expect(subject.rate_90).to eq(0.0)
          end
        end
      end

      context "given a post 91 days ago" do
        let_create!(:object, attributed_to: author, published: now - 91.days)

        it "does not count the post" do
          expect(subject.rate_90).to eq(0.0)
        end
      end

      context "given another author's post" do
        let_create(:actor, named: :other)
        let_create!(:object, attributed_to: other, published: now - 89.days)

        it "does not count the post" do
          expect(subject.rate_90).to eq(0.0)
        end
      end
    end
  end
end
