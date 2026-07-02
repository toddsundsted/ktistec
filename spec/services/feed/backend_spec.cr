require "../../../src/services/feed/backend"
require "../../../src/services/feed/backend/keyword"
require "../../../src/models/feed"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"

private class CannedBackend < Feed::Backend
  getter calls = [] of {Feed, Array(ActivityPub::Object)}

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
    calls << {feed, objects}
    objects.map { Judgment.new(included: true, reason: "canned") }
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

Spectator.describe Feed::Backend do
  setup_spec

  let(backend) { CannedBackend.new }

  around_each do |proc|
    begin
      proc.call
    ensure
      described_class.unregister("canned")
    end
  end

  describe ".register" do
    it "returns the backend" do
      expect(described_class.register("canned", backend)).to eq(backend)
    end
  end

  describe ".find?" do
    it "returns the registered backend" do
      described_class.register("canned", backend)
      expect(described_class.find?("canned")).to eq(backend)
    end

    it "returns the keyword backend" do
      expect(described_class.find?("keyword")).to be_a(Feed::Backend::Keyword)
    end

    it "returns nil" do
      expect(described_class.find?("missing")).to be_nil
    end
  end

  describe ".invoker" do
    let_build(:feed)
    let_build(:object)

    it "invokes the backend" do
      described_class.invoker.call(backend, feed, [object])
      expect(backend.calls).to eq([{feed, [object]}])
    end

    it "returns the backend's judgments" do
      judgments = described_class.invoker.call(backend, feed, [object])
      expect(judgments.map(&.included)).to eq([true])
    end
  end
end
