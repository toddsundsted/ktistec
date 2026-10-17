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

    it "selects the verdict's object at its creation time" do
      expect(selected).to contain({actor.iri, object.iri, object.created_at})
    end

    context "when the verdict is out" do
      before_each { feed_verdict.assign(included: false).save }

      pre_condition { expect(Feed::Verdict.count(version_id: feed.version_id, included: false)).to eq(1) }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "when the object is not visible" do
      before_each { object.update_property(:visible, false) }

      pre_condition { expect(Feed::Verdict.find(version_id: feed.version_id, object_iri: object.iri).included).to be_true }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end

      context "but is in the owner's inbox" do
        let_create(:create, object: object)

        before_each { put_in_inbox(actor, create) }

        it "selects the object" do
          expect(selected_iris).to contain(object.iri)
        end

        context "and its delivery is undone" do
          before_each { create.undo! }

          pre_condition { expect(create.undone?).to be_true }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end
      end
    end

    context "when the object is unpublished" do
      before_each { object.update_property(:published, nil) }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "when the object is special" do
      before_each { object.update_property(:special, "vote") }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "when the object is at the feed's floor" do
      before_each { feed.assign(floor: object.created_at).save }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "given a verdict of another feed on another version" do
      let_build(:object, named: other_object)
      let_create!(:feed, named: other_feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["other"]}})).as_h)
      let_create!(:feed_verdict, named: nil, feed: other_feed, object: other_object, included: true)

      pre_condition { expect(other_feed.version_id).not_to eq(feed.version_id) }

      it "does not select the object" do
        expect(selected_iris).not_to contain(other_object.iri)
      end
    end

    context "given a verdict of another feed on the same version" do
      let_build(:object, named: other_object)
      let_create!(:feed, named: other_feed, owner: actor, params: feed.params)
      let_create!(:feed_verdict, named: nil, feed: other_feed, object: other_object, included: true)

      pre_condition { expect(other_feed.version_id).to eq(feed.version_id) }

      it "selects the object" do
        expect(selected_iris).to contain(other_object.iri)
      end
    end

    context "when scoped" do
      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: object.iri}))
          .to eq([{actor.iri, object.iri, object.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: actor.iri, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the key as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: object.iri})
        expect(args).to eq([actor.iri, feed.id, "Relationship::Content::Inbox", "Relationship::Content::Outbox", actor.iri, object.iri])
      end
    end
  end

  # this is the only view whose membership carries base bind arguments
  # (and the only one that binds `from_iri` in the select list)

  describe "materializing a verdict" do
    let_build(:object)
    let_create!(:feed_verdict, feed: feed, object: object, included: true)

    it "materializes the row at the object's creation time" do
      Rules::Maintainer.reconcile_object_for(subject, object.iri)
      row = Ktistec.database.query_one(
        "SELECT from_iri, to_iri, created_at FROM relationships WHERE type = ?",
        subject.type, as: {String, String, Time})
      expect(row).to eq({actor.iri, object.iri, object.created_at})
    end
  end
end
