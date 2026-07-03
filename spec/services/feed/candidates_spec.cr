require "../../../src/services/feed/candidates"
require "../../../src/services/feed/backend/keyword"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Candidates do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor)

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

    context "when the object has a current-version verdict" do
      let_create!(:feed_verdict, feed: feed, object: object, included: false)

      pre_condition { expect(Feed::Verdict.count(feed_id: feed.id)).to eq(1) }

      it "does not return the object" do
        expect(candidates).to be_empty
      end

      context "and the feed's version is bumped" do
        before_each { feed.assign(version: 2).save }

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
end
