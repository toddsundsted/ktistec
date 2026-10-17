require "../../../src/models/feed/verdict"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Verdict do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(included: true)).to be_a(Feed::Verdict)
  end

  describe "validation" do
    let_build(:feed_verdict)

    it "is valid" do
      expect(feed_verdict.valid?).to be_true
    end

    context "when version and object are missing" do
      let_build(:feed_verdict, version: nil, object: nil)

      it "is invalid without a version" do
        expect(feed_verdict.valid?).to be_false
        expect(feed_verdict.errors.keys).to contain("version")
      end

      it "is invalid without an object" do
        expect(feed_verdict.valid?).to be_false
        expect(feed_verdict.errors.keys).to contain("object")
      end
    end

    context "given a failure" do
      let_build(:feed_verdict, included: false, failure: Feed::Verdict::TRANSIENT)

      it "is valid" do
        expect(feed_verdict.valid?).to be_true
      end

      context "and the failure is unsupported" do
        before_each { feed_verdict.failure = "unsupported" }

        it "is invalid" do
          expect(feed_verdict.valid?).to be_false
          expect(feed_verdict.errors.keys).to contain("failure")
        end
      end

      context "but the verdict is included" do
        before_each { feed_verdict.included = true }

        it "is invalid" do
          expect(feed_verdict.valid?).to be_false
          expect(feed_verdict.errors.keys).to contain("failure")
        end
      end
    end
  end

  describe "#excluded?" do
    it "is false for an included verdict" do
      expect(described_class.new(included: true).excluded?).to be_false
    end

    it "is true for an excluded verdict" do
      expect(described_class.new(included: false).excluded?).to be_true
    end

    it "is false for a failed verdict" do
      expect(described_class.new(included: false, failure: Feed::Verdict::PERMANENT).excluded?).to be_false
    end
  end

  describe "#failed?" do
    it "is false for an included verdict" do
      expect(described_class.new(included: true).failed?).to be_false
    end

    it "is false for an excluded verdict" do
      expect(described_class.new(included: false).failed?).to be_false
    end

    it "is true for a failed verdict" do
      expect(described_class.new(included: false, failure: Feed::Verdict::TRANSIENT).failed?).to be_true
    end
  end

  describe "persistence" do
    let_create(:feed_verdict, included: false, reason: "no keywords matched")

    it "round-trips through the database" do
      verdict = Feed::Verdict.find(feed_verdict.id)
      expect(verdict.included).to be_false
      expect(verdict.reason).to eq("no keywords matched")
    end
  end
end
