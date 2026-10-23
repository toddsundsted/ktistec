require "../../src/serializers/feed"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Serializers::Feed do
  setup_spec

  describe ".from" do
    let_build(:feed, name: "Cats", description: "Posts about cats", params: JSON.parse(%({"topic":"cats"})).as_h)

    subject { described_class.from(feed) }

    it "carries the feed's name" do
      expect(subject.name).to eq("Cats")
    end

    it "carries the feed's description" do
      expect(subject.description).to eq("Posts about cats")
    end

    it "carries the feed's params" do
      expect(subject.params).to eq({"topic" => JSON::Any.new("cats")})
    end
  end
end
