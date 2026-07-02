require "../../../../src/services/feed/backend/keyword"
require "../../../../src/models/feed"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Feed::Backend::Keyword do
  setup_spec

  subject { described_class.new }

  describe "#judge" do
    let_build(:feed, params: JSON.parse(%({"keywords": ["alpha", "beta"]})).as_h)
    let_build(:object, content: "<p>something alpha something</p>")

    let(judgment) { subject.judge(feed, [object]).first }

    it "includes an object whose content matches a keyword" do
      expect(judgment.included).to be_true
    end

    it "names the matched keyword in the reason" do
      expect(judgment.reason).to match(/alpha/)
    end

    context "given content that matches no keyword" do
      let_build(:object, content: "<p>gamma delta</p>")

      it "does not include the object" do
        expect(judgment.included).to be_false
      end

      it "explains in the reason" do
        expect(judgment.reason).to match(/matched 0 of 1/)
      end
    end

    context "given mixed-case content" do
      let_build(:object, content: "<p>ALPHA</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given content containing a keyword as a substring" do
      let_build(:object, content: "<p>alphabet</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a keyword split by markup" do
      let_build(:object, content: "<p><b>al</b>pha</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a keyword appearing only in markup" do
      let_build(:object, content: %q(<p><a href="https://alpha/">link</a></p>))

      it "does not include the object" do
        expect(judgment.included).to be_false
      end
    end

    context "given a threshold of 2" do
      let_build(:feed, params: JSON.parse(%({"keywords": ["alpha", "beta"], "threshold": 2})).as_h)

      it "does not include an object matching one keyword" do
        expect(judgment.included).to be_false
      end

      context "and content matching two keywords" do
        let_build(:object, content: "<p>alpha beta</p>")

        it "includes the object" do
          expect(judgment.included).to be_true
        end
      end
    end

    context "given a batch" do
      let_build(:object, named: miss, content: "<p>gamma</p>")
      let_build(:object, named: hit, content: "<p>alpha</p>")

      it "preserves order and identity" do
        expect(subject.judge(feed, [miss, hit]).map(&.included)).to eq([false, true])
      end
    end
  end

  describe "#validate_params" do
    it "accepts well-formed params" do
      params = JSON.parse(%({"keywords": ["alpha", "beta"], "threshold": 2})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    it "rejects missing keywords" do
      params = {} of String => JSON::Any
      expect(subject.validate_params(params)).to contain("keywords must be a non-empty array of non-blank strings")
    end

    it "rejects if not an array" do
      params = JSON.parse(%({"keywords": "alpha"})).as_h
      expect(subject.validate_params(params)).to contain("keywords must be a non-empty array of non-blank strings")
    end

    it "rejects an empty keywords array" do
      params = JSON.parse(%({"keywords": []})).as_h
      expect(subject.validate_params(params)).to contain("keywords must be a non-empty array of non-blank strings")
    end

    it "rejects keywords containing a non-string" do
      params = JSON.parse(%({"keywords": ["alpha", 1]})).as_h
      expect(subject.validate_params(params)).to contain("keywords must be a non-empty array of non-blank strings")
    end

    it "rejects keywords containing a blank string" do
      params = JSON.parse(%({"keywords": ["alpha", ""]})).as_h
      expect(subject.validate_params(params)).to contain("keywords must be a non-empty array of non-blank strings")
    end

    it "rejects keywords containing an empty string" do
      params = JSON.parse(%({"keywords": ["alpha", "  "]})).as_h
      expect(subject.validate_params(params)).to contain("keywords must be a non-empty array of non-blank strings")
    end

    it "rejects a threshold that is not an integer" do
      params = JSON.parse(%({"keywords": ["alpha"], "threshold": "high"})).as_h
      expect(subject.validate_params(params)).to contain("threshold must be a positive integer")
    end

    it "rejects a threshold less than 1" do
      params = JSON.parse(%({"keywords": ["alpha"], "threshold": 0})).as_h
      expect(subject.validate_params(params)).to contain("threshold must be a positive integer")
    end

    it "accepts a threshold equal to the number of keywords" do
      params = JSON.parse(%({"keywords": ["alpha", "beta"], "threshold": 2})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    it "rejects a threshold greater than the number of keywords" do
      params = JSON.parse(%({"keywords": ["alpha"], "threshold": 2})).as_h
      expect(subject.validate_params(params)).to contain("threshold must not exceed the number of keywords")
    end
  end
end
