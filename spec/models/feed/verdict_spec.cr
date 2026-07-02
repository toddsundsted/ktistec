require "../../../src/models/feed/verdict"
require "../../../src/services/feed/backend/keyword"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Verdict do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(included: true, position: Time.utc)).to be_a(Feed::Verdict)
  end

  describe "validation" do
    let_build(:feed_verdict)

    it "is valid" do
      expect(feed_verdict.valid?).to be_true
    end

    context "when feed and object are missing" do
      let_build(:feed_verdict, feed: nil, object: nil)

      it "is invalid without a feed" do
        expect(feed_verdict.valid?).to be_false
        expect(feed_verdict.errors.keys).to contain("feed")
      end

      it "is invalid without an object" do
        expect(feed_verdict.valid?).to be_false
        expect(feed_verdict.errors.keys).to contain("object")
      end
    end
  end

  describe "#version" do
    let_build(:feed_verdict)

    it "defaults to 1" do
      expect(feed_verdict.version).to eq(1)
    end
  end

  describe "persistence" do
    let(position) { Time.utc(2016, 2, 15, 10, 20, 0) }
    let_create(:feed_verdict, included: false, reason: "no keywords matched", version: 2, position: position)

    it "round-trips through the database" do
      verdict = Feed::Verdict.find(feed_verdict.id)
      expect(verdict.included).to be_false
      expect(verdict.reason).to eq("no keywords matched")
      expect(verdict.version).to eq(2)
      expect(verdict.position).to eq(position)
    end
  end
end
