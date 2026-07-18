require "../../../src/services/feed/candidates"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Candidates do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor)

  describe ".candidates_for" do
    let(candidates) { Feed::Candidates.candidates_for(feed) }

    it "returns no candidates" do
      expect(candidates).to be_empty
    end

    context "given a create in the owner's inbox" do
      let_build(:object)
      let_create(:create, object: object)
      let!(arrival) { put_in_inbox(actor, create).created_at }

      it "returns the object as a candidate" do
        expect(candidates.map(&.first)).to eq([object])
      end

      it "carries the arrival time" do
        expect(candidates.map(&.last)).to eq([arrival])
      end

      context "and a later announce of the same object" do
        let_create(:announce, object: object)
        before_each { put_in_inbox(actor, announce) }

        it "returns the object once" do
          expect(candidates.map(&.first)).to eq([object])
        end

        it "carries the first arrival time" do
          expect(candidates.map(&.last)).to eq([arrival])
        end
      end

      context "when the object has a verdict" do
        let_create!(:feed_verdict, feed: feed, object: object, included: false)

        it "does not return the object" do
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(1)
          expect(candidates).to be_empty
        end

        context "and the criteria change" do
          before_each { feed.assign(params: JSON.parse(%({"keywords": {"any": ["changed"]}})).as_h).save }

          it "returns the object" do
            expect(candidates.map(&.first)).to eq([object])
          end
        end
      end

      context "when the activity is undone" do
        before_each { create.undo! }

        pre_condition { expect(create.undone?).to be_true }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object is deleted" do
        before_each { object.delete! }

        pre_condition { expect(object.deleted?).to be_true }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object is blocked" do
        before_each { object.block! }

        pre_condition { expect(object.blocked?).to be_true }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object's author is blocked" do
        before_each { object.attributed_to.block! }

        pre_condition { expect(object.attributed_to.blocked?).to be_true }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object's author is deleted" do
        before_each { object.attributed_to.delete! }

        pre_condition { expect(object.attributed_to.deleted?).to be_true }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object is special" do
        before_each { object.assign(special: "vote").save }

        pre_condition { expect(object.special).to eq("vote") }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "with more creates" do
        let_build(:object, named: :object2)
        let_create(:create, named: :create2, object: object2)
        before_each { put_in_inbox(actor, create2) }

        let_build(:object, named: :object3)
        let_create(:create, named: :create3, object: object3)
        before_each { put_in_inbox(actor, create3) }

        it "returns candidates in arrival order" do
          expect(candidates.map(&.first)).to eq([object3, object2, object])
        end

        context "with a limit" do
          let(candidates) { Feed::Candidates.candidates_for(feed, limit: 2) }

          it "returns the most recently arrived candidates" do
            expect(candidates.map(&.first)).to eq([object3, object2])
          end
        end
      end
    end

    context "given a create in the owner's outbox" do
      let_build(:object)
      let_create(:create, object: object)
      before_each { put_in_outbox(actor, create) }

      pre_condition { expect(Relationship::Content::Outbox.count(from_iri: actor.iri)).to eq(1) }

      it "does not return the object" do
        expect(candidates).to be_empty
      end
    end

    context "given a create in another actor's inbox" do
      let(other) { register.actor }
      let_build(:object)
      let_create(:create, object: object)
      before_each { put_in_inbox(other, create) }

      pre_condition { expect(Relationship::Content::Inbox.count(from_iri: other.iri)).to eq(1) }

      it "does not return the object" do
        expect(candidates).to be_empty
      end
    end

    it "raises an error" do
      expect { Feed::Candidates.candidates_for(feed, limit: 0) }.to raise_error(ArgumentError, "limit must be positive")
    end

    it "raises an error" do
      expect { Feed::Candidates.candidates_for(feed, limit: -1) }.to raise_error(ArgumentError, "limit must be positive")
    end
  end

  describe ".arrival_for" do
    let_build(:object)

    it "returns nil" do
      expect(Feed::Candidates.arrival_for(feed, object)).to be_nil
    end

    context "given a create in the owner's inbox" do
      let_create(:create, object: object)
      let!(arrival) { put_in_inbox(actor, create).created_at }

      it "returns the arrival time" do
        expect(Feed::Candidates.arrival_for(feed, object)).to eq(arrival)
      end

      context "and a later announce of the same object" do
        let_create(:announce, object: object)
        before_each { put_in_inbox(actor, announce) }

        it "returns the earliest arrival time" do
          expect(Feed::Candidates.arrival_for(feed, object)).to eq(arrival)
        end
      end

      context "and the activity is undone" do
        before_each { create.undo! }

        it "returns nil" do
          expect(Feed::Candidates.arrival_for(feed, object)).to be_nil
        end
      end
    end

    context "given a create in the owner's outbox" do
      let_create(:create, object: object)
      before_each { put_in_outbox(actor, create) }

      pre_condition { expect(Relationship::Content::Outbox.count(from_iri: actor.iri)).to eq(1) }

      it "returns nil" do
        expect(Feed::Candidates.arrival_for(feed, object)).to be_nil
      end
    end
  end
end
