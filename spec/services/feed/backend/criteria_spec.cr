require "../../../../src/services/feed/backend/criteria"
require "../../../../src/models/feed"
require "../../../../src/models/tag/hashtag"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Feed::Backend::Criteria do
  setup_spec

  subject { described_class.new }

  describe "#judge" do
    let_build(:feed, params: JSON.parse(%({"keywords": {"any": ["alpha", "beta"]}})).as_h)
    let_build(:object, content: "<p>something alpha something</p>")

    let(judgment) { subject.judge(feed, [object]).first }

    it "includes an object matching an any term" do
      expect(judgment.included).to be_true
    end

    it "names the matched term in the reason" do
      expect(judgment.reason).to match(/alpha/)
    end

    context "given content that matches no term" do
      let_build(:object, content: "<p>gamma delta</p>")

      it "does not include the object" do
        expect(judgment.included).to be_false
      end
    end

    context "given mixed-case content" do
      let_build(:object, content: "<p>ALPHA</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a term matching as a substring" do
      let_build(:object, content: "<p>alphabet</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a term split by markup" do
      let_build(:object, content: "<p><b>al</b>pha</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a term appearing only in markup" do
      let_build(:object, content: %q(<p><a href="https://alpha/">link</a></p>))

      it "does not include the object" do
        expect(judgment.included).to be_false
      end
    end

    context "given a term matching only the name" do
      let_build(:object, content: "<p>gamma</p>", name: "alpha release")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a term matching only the summary" do
      let_build(:object, content: "<p>gamma</p>", summary: "<p>alpha</p>")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given all terms" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"all": ["alpha", "beta"]}})).as_h)

      it "does not include an object matching only one term" do
        expect(judgment.included).to be_false
      end

      context "and content matching every term" do
        let_build(:object, content: "<p>alpha beta</p>")

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the matched terms in the reason" do
          expect(judgment.reason).to match(/alpha/)
          expect(judgment.reason).to match(/beta/)
        end
      end
    end

    context "given any and all terms" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": ["alpha"], "all": ["beta"]}})).as_h)
      let_build(:object, content: "<p>beta</p>")

      it "does not include an object matching only the all term" do
        expect(judgment.included).to be_false
      end
    end

    context "given a non-string term" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": [1]}})).as_h)

      it "does not include the object" do
        expect(judgment.included).to be_false
      end
    end

    context "given a blank term" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": [""]}})).as_h)

      it "does not include the object" do
        expect(judgment.included).to be_false
      end
    end

    context "given a none term that also matches" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": ["alpha"], "none": ["beta"]}})).as_h)
      let_build(:feed, named: without_none, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
      let_build(:object, content: "<p>alpha beta</p>")

      # the any term matches -- absent the none term the object is in
      pre_condition { expect(subject.judge(without_none, [object]).first.included).to be_true }

      it "does not include the object" do
        expect(judgment.included).to be_false
      end

      it "names the excluded term in the reason" do
        expect(judgment.reason).to match(/beta/)
      end
    end

    context "given a batch" do
      let_build(:object, named: miss, content: "<p>gamma</p>")
      let_build(:object, named: hit, content: "<p>alpha</p>")

      it "preserves order and identity" do
        expect(subject.judge(feed, [miss, hit]).map(&.included)).to eq([false, true])
      end
    end

    context "given a hashtags any group" do
      let_build(:feed, params: JSON.parse(%({"hashtags": {"any": ["3dprinting"]}})).as_h)
      let_create!(:object, content: "<p>plain</p>")

      it "does not include an untagged object" do
        expect(judgment.included).to be_false
      end

      context "and the object carries the tag" do
        let_create!(:hashtag, subject: object, name: "3dprinting")

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the tag in the reason" do
          expect(judgment.reason).to match(/3dprinting/)
        end
      end

      context "and the object carries the tag in mixed case" do
        let_create!(:hashtag, subject: object, name: "3DPrinting")

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the tag in the reason" do
          expect(judgment.reason).to match(/3dprinting/)
        end
      end

      context "and the term is a substring of the tag" do
        let_create!(:hashtag, subject: object, name: "3dprintingtips")

        it "does not include the object" do
          expect(judgment.included).to be_false
        end
      end
    end

    context "given a hashtags all group" do
      let_build(:feed, params: JSON.parse(%({"hashtags": {"all": ["3dprinting", "prusa"]}})).as_h)
      let_create!(:object, content: "<p>plain</p>")
      let_create!(:hashtag, subject: object, name: "3dprinting")

      it "does not include an object carrying only one tag" do
        expect(judgment.included).to be_false
      end

      context "and the object carries all tags" do
        let_create!(:hashtag, named: prusa_tag, subject: object, name: "prusa")

        it "includes the object" do
          expect(judgment.included).to be_true
        end
      end
    end

    context "given a hashtags term with a leading hash" do
      let_build(:feed, params: JSON.parse(%({"hashtags": {"any": ["#3dprinting"]}})).as_h)
      let_create!(:object, content: "<p>plain</p>")
      let_create!(:hashtag, subject: object, name: "3dprinting")

      it "includes the object" do
        expect(judgment.included).to be_true
      end
    end

    context "given a keyword any match and a hashtag none" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": ["alpha"]}, "hashtags": {"none": ["spoiler"]}})).as_h)
      let_build(:feed, named: without_none, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
      let_create!(:object, content: "<p>alpha</p>")
      let_create!(:hashtag, subject: object, name: "spoiler")

      pre_condition { expect(subject.judge(without_none, [object]).first.included).to be_true }

      it "does not include the object" do
        expect(judgment.included).to be_false
      end

      it "names the excluded tag in the reason" do
        expect(judgment.reason).to match(/spoiler/)
      end
    end
  end

  describe "#validate_params" do
    it "accepts a well-formed group" do
      params = JSON.parse(%({"keywords": {"any": ["alpha"], "all": ["beta"], "none": ["gamma"]}})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    it "rejects a keywords array" do
      params = JSON.parse(%({"keywords": ["alpha", "beta"]})).as_h
      expect(subject.validate_params(params)).to contain("keywords must be an object with any, all, or none")
    end

    it "rejects an unknown group" do
      params = JSON.parse(%({"keywords": {"any": ["alpha"]}, "threshold": 2})).as_h
      expect(subject.validate_params(params)).to contain("unknown groups: threshold")
    end

    it "rejects an unknown selector" do
      params = JSON.parse(%({"keywords": {"any": ["alpha"], "most": ["beta"]}})).as_h
      expect(subject.validate_params(params)).to contain("keywords has unknown selectors: most")
    end

    it "rejects a selector that is not an array" do
      params = JSON.parse(%({"keywords": {"any": "alpha"}})).as_h
      expect(subject.validate_params(params)).to contain("keywords any must be an array of non-blank strings")
    end

    it "rejects a selector containing a non-string" do
      params = JSON.parse(%({"keywords": {"any": ["alpha", 1]}})).as_h
      expect(subject.validate_params(params)).to contain("keywords any must be an array of non-blank strings")
    end

    it "rejects a selector containing a blank string" do
      params = JSON.parse(%({"keywords": {"any": ["alpha", "  "]}})).as_h
      expect(subject.validate_params(params)).to contain("keywords any must be an array of non-blank strings")
    end

    it "rejects a group with no positive terms" do
      params = JSON.parse(%({"keywords": {"none": ["gamma"]}})).as_h
      expect(subject.validate_params(params)).to contain("at least one any or all term is required")
    end

    it "rejects a group with only empty positive lists" do
      params = JSON.parse(%({"keywords": {"any": []}})).as_h
      expect(subject.validate_params(params)).to contain("at least one any or all term is required")
    end

    it "accepts a hashtags group" do
      params = JSON.parse(%({"hashtags": {"any": ["3dprinting"]}})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    it "accepts combined keywords and hashtags groups" do
      params = JSON.parse(%({"keywords": {"any": ["alpha"]}, "hashtags": {"none": ["spoiler"]}})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    it "rejects an unknown selector in the hashtags group" do
      params = JSON.parse(%({"hashtags": {"any": ["3dprinting"], "most": ["prusa"]}})).as_h
      expect(subject.validate_params(params)).to contain("hashtags has unknown selectors: most")
    end

    it "rejects a hashtags array" do
      params = JSON.parse(%({"hashtags": ["3dprinting"]})).as_h
      expect(subject.validate_params(params)).to contain("hashtags must be an object with any, all, or none")
    end

    it "rejects params with no positive terms across groups" do
      params = JSON.parse(%({"hashtags": {"none": ["spoiler"]}})).as_h
      expect(subject.validate_params(params)).to contain("at least one any or all term is required")
    end
  end
end
