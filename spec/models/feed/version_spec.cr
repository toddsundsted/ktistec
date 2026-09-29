require "../../../src/models/feed/version"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"

Spectator.describe Feed::Version do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(backend: "criteria", params: "{}")).to be_a(Feed::Version)
  end

  describe ".for" do
    let(params) { JSON.parse(%({"keywords": {"any": ["alpha", "beta"]}, "hashtags": {"any": ["gamma"]}})).as_h }

    subject { described_class.for("criteria", params) }

    it "creates a version" do
      expect { subject }.to change { described_class.count }.by(1)
    end

    context "given an existing version" do
      let!(existing) { described_class.for("criteria", JSON.parse(%({"keywords": {"any": ["alpha", "beta"]}, "hashtags": {"any": ["gamma"]}})).as_h) }

      it "returns the existing version" do
        expect(subject).to eq(existing)
      end

      context "and params in another order" do
        let(params) { JSON.parse(%({"hashtags": {"any": ["gamma"]}, "keywords": {"any": ["alpha", "beta"]}})).as_h }

        it "returns the existing version" do
          expect(subject).to eq(existing)
        end
      end

      context "and params with ignored keys" do
        let(params) { JSON.parse(%({"keywords": {"any": ["alpha", "beta"]}, "hashtags": {"any": ["gamma"]}, "order": {"any": ["beta"]}})).as_h }

        it "returns the existing version" do
          expect(subject).to eq(existing)
        end
      end

      context "and different params" do
        let(params) { JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h }

        it "returns another version" do
          expect(subject).not_to eq(existing)
        end
      end

      context "and another backend" do
        private class AnotherBackend < TestBackend
          def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
            objects.map { Judgment.new(included: true) }
          end

          def validate_params(params : Hash(String, JSON::Any)) : Array(String)
            [] of String
          end
        end

        around_each do |proc|
          Feed::Backend.register("another", AnotherBackend.new)
          begin
            proc.call
          ensure
            Feed::Backend.unregister("another")
          end
        end

        subject { described_class.for("another", params) }

        it "returns another version" do
          expect(subject).not_to eq(existing)
        end
      end
    end

    context "given an unregistered backend" do
      subject { described_class.for("unregistered", params) }

      it "raises an error" do
        expect { subject }.to raise_error(/is not a registered backend/)
      end
    end
  end
end
