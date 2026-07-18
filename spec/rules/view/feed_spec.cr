require "../../../src/rules/view/feed"
require "../../../src/rules/maintainer"
require "../../../src/models/feed"
require "../../../src/models/feed/verdict"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::Feed do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor)

  subject { Rules::View::Feed.new(feed_id: feed.id.not_nil!, owner_iri: actor.iri) }

  describe "registry" do
    it "is not registered" do
      expect(Rules::View.registry.none?(Rules::View::Feed)).to be_true
    end
  end

  describe "#type" do
    it "returns the feed's synthetic relationship type" do
      expect(subject.type).to eq(feed.feed_type)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#subjects" do
    it "publishes to a feed's subject" do
      expect(subject.subjects("alice")).to eq(["/actors/alice/feeds/#{feed.id}"])
    end
  end

  describe "#project" do
    it "maps to the feed owner's key" do
      expect(subject.project("https://remote/objects/1"))
        .to eq([{from_iri: actor.iri, to_iri: "https://remote/objects/1"}])
    end
  end

  describe "#membership" do
    let_build(:object)
    let_create!(:feed_verdict, feed: feed, object: object, included: true)

    it "selects the verdict's object at its position" do
      expect(selected).to contain({actor.iri, object.iri, feed_verdict.position})
    end

    context "when the verdict is out" do
      before_each { feed_verdict.assign(included: false).save }

      pre_condition { expect(Feed::Verdict.count(feed_id: feed.id, included: false)).to eq(1) }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "when the object is deleted" do
      before_each { object.delete! }

      pre_condition { expect(object.deleted?).to be_true }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "given another feed's verdict" do
      let_build(:object, named: other_object)
      let_create!(:feed, named: other_feed, owner: actor)
      let_create!(:feed_verdict, named: nil, feed: other_feed, object: other_object, included: true)

      pre_condition { expect(Feed::Verdict.count(feed_id: other_feed.id, included: true)).to eq(1) }

      it "does not select the object" do
        expect(selected_iris).not_to contain(other_object.iri)
      end
    end

    context "when scoped" do
      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: object.iri}))
          .to eq([{actor.iri, object.iri, feed_verdict.position}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: actor.iri, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the key as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: object.iri})
        expect(args).to eq([actor.iri, feed.id, object.iri])
      end
    end
  end

  # this is the only view whose membership carries base bind arguments
  # (and the only one that binds `from_iri` in the select list)

  describe "materializing a verdict" do
    let_build(:object)
    let_create!(:feed_verdict, feed: feed, object: object, included: true)

    it "materializes the row at the verdict's position" do
      Rules::Maintainer.reconcile_object_for(subject, object.iri)
      row = Ktistec.database.query_one(
        "SELECT from_iri, to_iri, created_at FROM relationships WHERE type = ?",
        subject.type, as: {String, String, Time})
      expect(row).to eq({actor.iri, object.iri, feed_verdict.position})
    end
  end
end
