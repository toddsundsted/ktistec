require "../../spec_helper/base"
require "../../spec_helper/factory"

require "../../../src/api/serializers/relationship"

Spectator.describe API::V1::Serializers::Relationship do
  setup_spec

  describe ".from_actors" do
    let_create(:actor, named: :actor, local: true, with_keys: true)
    let_create(:actor, named: :other, local: true, with_keys: true)

    subject { described_class.from_actors(actor, other) }

    it "returns id" do
      expect(subject.id).to eq(other.id.to_s)
    end

    it "returns following" do
      expect(subject.following).to be_false
    end

    it "returns showing_reblogs" do
      expect(subject.showing_reblogs).to be_true
    end

    it "returns notifying" do
      expect(subject.notifying).to be_false
    end

    it "returns followed_by" do
      expect(subject.followed_by).to be_false
    end

    it "returns blocking" do
      expect(subject.blocking).to be_false
    end

    it "returns blocked_by" do
      expect(subject.blocked_by).to be_false
    end

    it "returns muting" do
      expect(subject.muting).to be_false
    end

    it "returns muting_notifications" do
      expect(subject.muting_notifications).to be_false
    end

    it "returns requested" do
      expect(subject.requested).to be_false
    end

    it "returns requested_by" do
      expect(subject.requested_by).to be_false
    end

    it "returns domain_blocking" do
      expect(subject.domain_blocking).to be_false
    end

    it "returns endorsed" do
      expect(subject.endorsed).to be_false
    end

    it "returns note" do
      expect(subject.note).to eq("")
    end

    context "when following other" do
      let_create!(:follow_relationship, actor: actor, object: other, confirmed: true)
      let_create!(:follow, named: :follow_activity, actor: actor, object: other)
      let_create!(:accept, named: nil, actor: other, object: follow_activity)

      it "returns following" do
        expect(subject.following).to be_true
      end
    end

    context "when followed by other" do
      let_create!(:follow_relationship, actor: other, object: actor, confirmed: true)
      let_create!(:follow, named: :follow_activity, actor: other, object: actor)
      let_create!(:accept, named: nil, actor: actor, object: follow_activity)

      it "returns followed_by" do
        expect(subject.followed_by).to be_true
      end
    end

    context "when other is blocked" do
      before_each { other.block! }

      it "returns blocking" do
        expect(subject.blocking).to be_true
      end
    end

    context "with pending follow request" do
      let_create!(:follow_relationship, actor: actor, object: other, confirmed: false, visible: false)

      it "returns requested" do
        expect(subject.requested).to be_true
      end

      it "returns following" do
        expect(subject.following).to be_false
      end
    end
  end
end
