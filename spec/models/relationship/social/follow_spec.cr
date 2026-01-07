require "../../../../src/models/relationship/social/follow"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Social::Follow do
  setup_spec

  let_create(:actor, named: from)
  let_create(:actor, named: to)

  let(options) do
    {
      from_iri: from.iri,
      to_iri:   to.iri,
    }
  end

  context "validation" do
    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("actor")
    end

    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("object")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  context "#activity?" do
    let_build(:follow_relationship)

    it "returns nil" do
      expect(follow_relationship.activity?).to be_nil
    end

    context "given an associated follow activity" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)

      it "returns the associated follow activity" do
        expect(follow_relationship.activity?).to eq(follow)
      end

      context "that has been undone" do
        before_each { follow.undo! }

        it "returns nil" do
          expect(follow_relationship.activity?).to be_nil
        end
      end
    end

    context "given multiple associated follow activities" do
      let_create!(:follow, named: oldest, actor: follow_relationship.actor, object: follow_relationship.object, created_at: 3.days.ago)
      let_create!(:follow, named: newest, actor: follow_relationship.actor, object: follow_relationship.object, created_at: 1.day.ago)
      let_create!(:follow, named: older, actor: follow_relationship.actor, object: follow_relationship.object, created_at: 2.days.ago)

      it "returns the most recent follow activity" do
        expect(follow_relationship.activity?).to eq(newest)
      end
    end
  end

  context ".followers_for" do
    let_create(:actor, named: followed_actor)
    let_create(:actor, named: follower1)
    let_create(:actor, named: follower2)

    context "with multiple followers" do
      let_create!(:follow_relationship, named: nil, actor: follower1, object: followed_actor, confirmed: true)
      let_create!(:follow_relationship, named: nil, actor: follower2, object: followed_actor, confirmed: false)

      it "returns followers for the given actor" do
        followers = described_class.followers_for(followed_actor.iri)
        expect(followers.size).to eq(2)
        expect(followers.map(&.from_iri)).to contain_exactly(follower2.iri, follower1.iri)
      end

      it "supports pagination" do
        followers = described_class.followers_for(followed_actor.iri, page: 1, size: 1)
        expect(followers.size).to eq(1)
        expect(followers.more?).to be_true
      end
    end
  end

  context ".following_for" do
    let_create(:actor, named: following_actor)
    let_create(:actor, named: followed1)
    let_create(:actor, named: followed2)

    context "with multiple following" do
      let_create!(:follow_relationship, named: nil, actor: following_actor, object: followed1, confirmed: true)
      let_create!(:follow_relationship, named: nil, actor: following_actor, object: followed2, confirmed: false)

      it "returns following for the given actor" do
        following = described_class.following_for(following_actor.iri)
        expect(following.size).to eq(2)
        expect(following.map(&.to_iri)).to contain_exactly(followed2.iri, followed1.iri)
      end

      it "supports pagination" do
        following = described_class.following_for(following_actor.iri, page: 1, size: 1)
        expect(following.size).to eq(1)
        expect(following.more?).to be_true
      end
    end
  end

  context ".followers_since" do
    let_create(:actor, named: followed_actor)
    let_create(:actor, named: follower1)
    let_create(:actor, named: follower2)

    context "with followers created at different times" do
      let_create!(:follow_relationship, named: old_follow, actor: follower1, object: followed_actor, created_at: 2.days.ago)
      let_create!(:follow_relationship, named: new_follow, actor: follower2, object: followed_actor, created_at: 1.hour.ago)

      it "returns count since timestamp" do
        count = described_class.followers_since(followed_actor.iri, 1.day.ago)
        expect(count).to eq(1)
      end

      it "returns total number" do
        count = described_class.followers_since(followed_actor.iri, 3.days.ago)
        expect(count).to eq(2)
      end

      it "returns zero" do
        count = described_class.followers_since(followed_actor.iri, Time.utc)
        expect(count).to eq(0)
      end
    end
  end

  context ".following_since" do
    let_create(:actor, named: following_actor)
    let_create(:actor, named: followed1)
    let_create(:actor, named: followed2)

    context "with following created at different times" do
      let_create!(:follow_relationship, named: old_follow, actor: following_actor, object: followed1, created_at: 2.days.ago)
      let_create!(:follow_relationship, named: new_follow, actor: following_actor, object: followed2, created_at: 1.hour.ago)

      it "returns count since timestamp" do
        count = described_class.following_since(following_actor.iri, 1.day.ago)
        expect(count).to eq(1)
      end

      it "returns total number" do
        count = described_class.following_since(following_actor.iri, 3.days.ago)
        expect(count).to eq(2)
      end

      it "returns zero" do
        count = described_class.following_since(following_actor.iri, Time.utc)
        expect(count).to eq(0)
      end
    end
  end

  describe "#accepted?" do
    let_create!(:follow_relationship)

    context "when no follow activity exists" do
      it "returns false" do
        expect(follow_relationship.accepted?).to be_falsey
      end
    end

    context "when follow activity exists but no accept/reject" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)

      it "returns false" do
        expect(follow_relationship.accepted?).to be_falsey
      end
    end

    context "when follow activity has been accepted" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)
      let_create!(:accept, actor: follow_relationship.object, object: follow)

      it "returns true" do
        expect(follow_relationship.accepted?).to be_truthy
      end
    end

    context "when follow activity has been rejected" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)
      let_create!(:reject, actor: follow_relationship.object, object: follow)

      it "returns false" do
        expect(follow_relationship.accepted?).to be_falsey
      end
    end
  end

  describe "#rejected?" do
    let_create!(:follow_relationship)

    context "when no follow activity exists" do
      it "returns false" do
        expect(follow_relationship.rejected?).to be_falsey
      end
    end

    context "when follow activity exists but no accept/reject" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)

      it "returns false" do
        expect(follow_relationship.rejected?).to be_falsey
      end
    end

    context "when follow activity has been accepted" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)
      let_create!(:accept, actor: follow_relationship.object, object: follow)

      it "returns false" do
        expect(follow_relationship.rejected?).to be_falsey
      end
    end

    context "when follow activity has been rejected" do
      let_create!(:follow, actor: follow_relationship.actor, object: follow_relationship.object)
      let_create!(:reject, actor: follow_relationship.object, object: follow)

      it "returns true" do
        expect(follow_relationship.rejected?).to be_truthy
      end
    end
  end

  describe "#pending?" do
    let_create!(:follow_relationship)

    context "when confirmed is false" do
      before_each { follow_relationship.assign(confirmed: false).save }

      it "returns true" do
        expect(follow_relationship.pending?).to be_truthy
      end
    end

    context "when confirmed is true" do
      before_each { follow_relationship.assign(confirmed: true).save }

      it "returns false" do
        expect(follow_relationship.pending?).to be_falsey
      end
    end
  end
end
