require "../../../../src/models/relationship/social/follow"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Social::Follow do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: Factory.create(:actor).iri
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
