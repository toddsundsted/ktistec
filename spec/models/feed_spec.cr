require "../../src/models/feed"
require "../../src/services/feed/backend/keyword"

require "../spec_helper/base"
require "../spec_helper/factory"
require "../spec_helper/feed/backend"

private class RejectingBackend < Feed::Backend
  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
    objects.map { Judgment.new(included: false) }
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    ["is rejected"]
  end
end

Spectator.describe Feed do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(name: "name", backend: "keyword")).to be_a(Feed)
  end

  describe "validation" do
    let_build(:feed)

    it "is valid" do
      expect(feed.valid?).to be_true
    end

    context "when owner is missing" do
      let_build(:feed, owner: nil)

      it "is invalid" do
        expect(feed.valid?).to be_false
        expect(feed.errors.keys).to contain("owner")
      end
    end

    context "when name is blank" do
      before_each { feed.assign(name: "") }

      it "is invalid" do
        expect(feed.valid?).to be_false
        expect(feed.errors["name"]?).to contain("can't be blank")
      end
    end

    context "when backend is not registered" do
      before_each { feed.assign(backend: "missing") }

      it "is invalid" do
        expect(feed.valid?).to be_false
        expect(feed.errors["backend"]?).to contain("is not a registered backend: missing")
      end
    end

    context "when the backend rejects the params" do
      around_each do |proc|
        Feed::Backend.register("rejecting", RejectingBackend.new)
        begin
          proc.call
        ensure
          Feed::Backend.unregister("rejecting")
        end
      end

      before_each { feed.assign(backend: "rejecting") }

      it "is invalid" do
        expect(feed.valid?).to be_false
        expect(feed.errors["params"]?).to contain("is rejected")
      end
    end
  end

  describe "#version" do
    let_build(:feed)

    it "defaults to 1" do
      expect(feed.version).to eq(1)
    end
  end

  describe "#params" do
    let_create(:feed, params: JSON.parse(%({"keywords": ["alpha", "beta"], "threshold": 2})).as_h)

    it "round-trips through the database" do
      params = Feed.find(feed.id).params
      expect(params["keywords"].as_a.map(&.as_s)).to eq(["alpha", "beta"])
      expect(params["threshold"].as_i).to eq(2)
    end
  end

  describe "#examples" do
    let_create(:feed, examples: [Feed::Example.new("https://remote/objects/1", true)])

    it "round-trips through the database" do
      examples = Feed.find(feed.id).examples
      expect(examples.size).to eq(1)
      expect(examples.first.object_iri).to eq("https://remote/objects/1")
      expect(examples.first.included).to be_true
    end
  end

  describe "#feed_type" do
    let_create(:feed)

    it "returns the synthetic per-feed relationship type" do
      expect(feed.feed_type).to eq("Feed::#{feed.id}")
    end
  end

  describe "#contents" do
    let(actor) { register.actor }

    let_create(:feed, owner: actor)

    it "returns an empty collection" do
      expect(feed.contents).to be_empty
    end

    context "given objects in the feed" do
      macro post(index)
        let_build(:actor, named: actor{{index}})
        let_create(:object, named: object{{index}}, attributed_to: actor{{index}})
        before_each { put_in_feed(feed, object{{index}}) }
      end

      post(1)
      post(2)
      post(3)
      post(4)

      it "returns the most recently objects first" do
        expect(feed.contents).to eq([object4, object3, object2, object1])
      end

      it "filters out deleted objects" do
        object4.delete!
        expect(feed.contents).to eq([object3, object2, object1])
      end

      it "filters out blocked objects" do
        object4.block!
        expect(feed.contents).to eq([object3, object2, object1])
      end

      it "filters out objects by deleted actors" do
        actor4.delete!
        expect(feed.contents).to eq([object3, object2, object1])
      end

      it "filters out objects by blocked actors" do
        actor4.block!
        expect(feed.contents).to eq([object3, object2, object1])
      end

      context "given an object not in the feed" do
        let_create!(:object, named: nil)

        it "does not include the object" do
          expect(feed.contents).to eq([object4, object3, object2, object1])
        end
      end

      context "given an object in another feed" do
        let_create(:feed, named: other, owner: actor)
        let_create(:object, named: another)

        before_each { put_in_feed(other, another) }

        it "does not include the object" do
          expect(feed.contents).to eq([object4, object3, object2, object1])
        end
      end

      it "sets the cursors to object ids" do
        contents = feed.contents(limit: 2)
        expect(contents.cursor_start).to eq(object4.id)
        expect(contents.cursor_end).to eq(object3.id)
      end

      it "paginates the results" do
        expect(feed.contents(max_id: object3.id, limit: 2)).to eq([object2, object1])
        expect(feed.contents(max_id: object3.id, limit: 2).has_next?).not_to be_true
      end

      it "paginates the results" do
        expect(feed.contents(min_id: object1.id, limit: 2)).to eq([object3, object2])
        expect(feed.contents(min_id: object1.id, limit: 2).has_prev?).to be_true
      end
    end
  end
end
