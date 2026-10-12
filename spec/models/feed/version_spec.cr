require "../../../src/models/feed/version"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"

Spectator.describe Feed::Version do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(owner_iri: "https://test.test/actors/owner", backend: "criteria", params: "{}")).to be_a(Feed::Version)
  end

  describe ".for" do
    let_create(:actor, named: owner)
    let(params) { JSON.parse(%({"keywords": {"any": ["alpha", "beta"]}, "hashtags": {"any": ["gamma"]}})).as_h }

    subject { described_class.for(owner, "criteria", params) }

    it "creates a version" do
      expect { subject }.to change { described_class.count }.by(1)
    end

    context "given an existing version" do
      let!(existing) { described_class.for(owner, "criteria", JSON.parse(%({"keywords": {"any": ["alpha", "beta"]}, "hashtags": {"any": ["gamma"]}})).as_h) }

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

      context "and another owner" do
        let_create(:actor, named: another)

        subject { described_class.for(another, "criteria", params) }

        it "returns another version" do
          expect(subject).not_to eq(existing)
        end
      end

      context "and another backend" do
        private class AnotherBackend < TestBackend
          def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
            objects.map { Judgment.new(included: true).as(Judgment | Failure) }
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

        subject { described_class.for(owner, "another", params) }

        it "returns another version" do
          expect(subject).not_to eq(existing)
        end
      end
    end

    context "given an unregistered backend" do
      subject { described_class.for(owner, "unregistered", params) }

      it "raises an error" do
        expect { subject }.to raise_error(/is not a registered backend/)
      end
    end
  end

  describe "#cover_down_to" do
    let_create(:feed_version, named: version)

    it "sets the mark" do
      version.cover_down_to(5_i64)
      expect(version.backfill_cursor).to eq(5)
    end

    it "saves the mark" do
      version.cover_down_to(5_i64)
      expect(described_class.find(version.id).backfill_cursor).to eq(5)
    end

    context "given a lower mark saved through another instance" do
      before_each { described_class.find(version.id).cover_down_to(3_i64) }

      pre_condition { expect(version.backfill_cursor).to be_nil }

      it "keeps the lower mark" do
        version.cover_down_to(5_i64)
        expect(version.backfill_cursor).to eq(3)
      end
    end
  end
end
