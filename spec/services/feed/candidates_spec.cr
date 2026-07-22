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

  describe ".mailbox_rows_for" do
    let(cursor) { nil }
    let(limit) { 10 }

    let(rows) { Feed::Candidates.mailbox_rows_for(feed, cursor, limit) }

    it "returns no rows" do
      expect(rows).to be_empty
    end

    context "given creates in the owner's inbox" do
      let_build(:object, named: :object1)
      let_create(:create, named: :create1, object: object1)
      let!(row1) { put_in_inbox(actor, create1) }

      let_build(:object, named: :object2)
      let_create(:create, named: :create2, object: object2)
      let!(row2) { put_in_inbox(actor, create2) }

      let_build(:object, named: :object3)
      let_create(:create, named: :create3, object: object3)
      let!(row3) { put_in_inbox(actor, create3) }

      it "returns the rows newest first" do
        expect(rows.map(&.object)).to eq([object3, object2, object1])
      end

      it "carries the mailbox row id" do
        expect(rows.map(&.id)).to eq([row3.id, row2.id, row1.id])
      end

      it "carries the time the post arrived" do
        expect(rows.map(&.created_at)).to eq([row3.created_at, row2.created_at, row1.created_at])
      end

      context "with a limit" do
        let(limit) { 2 }

        it "returns the most recently arrived" do
          expect(rows.map(&.object)).to eq([object3, object2])
        end
      end

      context "with a cursor" do
        let(cursor) { row3.id }

        it "does not return the row at the cursor" do
          expect(rows.map(&.object)).to eq([object2, object1])
        end
      end

      context "when a post has a verdict" do
        let_create!(:feed_verdict, feed: feed, object: object3, included: true)

        it "does not return its row" do
          expect(rows.map(&.object)).to eq([object2, object1])
        end
      end

      context "and a later announce of the same post" do
        let_create(:announce, object: object1)
        let!(row4) { put_in_inbox(actor, announce) }

        it "returns the post once per arrival" do
          expect(rows.map(&.object)).to eq([object1, object3, object2, object1])
        end

        it "returns a row per arrival" do
          expect(rows.map(&.id)).to eq([row4.id, row3.id, row2.id, row1.id])
        end
      end
    end

    it "raises an error" do
      expect { Feed::Candidates.mailbox_rows_for(feed, cursor, 0) }.to raise_error(ArgumentError, "limit must be positive")
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

      context "and the object is deleted" do
        before_each { object.delete! }

        it "returns nil" do
          expect(Feed::Candidates.arrival_for(feed, object)).to be_nil
        end
      end

      context "and the object's author is deleted" do
        before_each { object.attributed_to.delete! }

        it "returns nil" do
          expect(Feed::Candidates.arrival_for(feed, object)).to be_nil
        end
      end

      # blocking is reversible

      context "and the object is blocked" do
        before_each { object.block! }

        it "returns the arrival time" do
          expect(Feed::Candidates.arrival_for(feed, object)).to eq(arrival)
        end
      end

      context "and the object's author is blocked" do
        before_each { object.attributed_to.block! }

        it "returns the arrival time" do
          expect(Feed::Candidates.arrival_for(feed, object)).to eq(arrival)
        end
      end

      context "and the object is special" do
        before_each { object.assign(special: "vote").save }

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
