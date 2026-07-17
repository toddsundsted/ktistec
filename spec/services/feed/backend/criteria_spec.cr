require "../../../../src/services/feed/backend/criteria"
require "../../../../src/models/feed"
require "../../../../src/models/tag/hashtag"
require "../../../../src/models/tag/mention"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Feed::Backend::Criteria do
  setup_spec

  subject { described_class.new }

  def one(group : String, selector : String, term : String) : Hash(String, JSON::Any)
    {group => JSON::Any.new({selector => JSON::Any.new([JSON::Any.new(term)])})}
  end

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
      let_build(:feed, params: JSON.parse(%({"hashtags": {"all": ["3dprinting", "filament"]}})).as_h)
      let_create!(:object, content: "<p>plain</p>")
      let_create!(:hashtag, subject: object, name: "3dprinting")

      it "does not include an object carrying only one tag" do
        expect(judgment.included).to be_false
      end

      context "and the object carries all tags" do
        let_create!(:hashtag, named: filament_tag, subject: object, name: "filament")

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

    context "given any terms in keywords and hashtags" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": ["alpha"]}, "hashtags": {"any": ["filament"]}})).as_h)

      context "and only the keyword any matches" do
        let_create!(:object, content: "<p>alpha</p>")

        it "includes the object" do
          expect(judgment.included).to be_true
        end
      end

      context "and only the hashtag any matches" do
        let_create!(:object, content: "<p>plain</p>")
        let_create!(:hashtag, subject: object, name: "filament")

        it "includes the object" do
          expect(judgment.included).to be_true
        end
      end

      context "and neither any matches" do
        let_create!(:object, content: "<p>plain</p>")

        it "does not include the object" do
          expect(judgment.included).to be_false
        end
      end
    end

    context "given a mentions group" do
      let_create!(:object, content: "<p>plain</p>")
      let_create!(:mention, subject: object, name: "alice@example.com", href: "https://example.com/actors/alice")

      it "does not include an unmentioned object" do
        expect(judgment.included).to be_false
      end

      context "and a mentions any group with a handle" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["alice@example.com"]}})).as_h)

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the handle in the reason" do
          expect(judgment.reason).to match(/alice@example.com/)
        end
      end

      context "and a mentions term with a leading at sign" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["@alice@example.com"]}})).as_h)

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the handle in the reason" do
          expect(judgment.reason).to match(/alice@example.com/)
        end
      end

      context "and a mentions term with mixed case" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["alice@EXAMPLE.com"]}})).as_h)

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the handle in the reason" do
          expect(judgment.reason).to match(/alice@example.com/)
        end
      end

      context "and a mentions term with a port" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["alice@example.com:3000"]}})).as_h)

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the handle in the reason" do
          expect(judgment.reason).to match(/alice@example.com/)
        end
      end

      context "and a mentions any group with an IRI" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["https://example.com/actors/alice"]}})).as_h)

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the IRI in the reason" do
          expect(judgment.reason).to match(/https:\/\/example.com\/actors\/alice/)
        end
      end

      context "and a mentions term with mixed case" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["https://EXAMPLE.com/actors/alice"]}})).as_h)

        it "includes the object" do
          expect(judgment.included).to be_true
        end

        it "names the IRI in the reason" do
          expect(judgment.reason).to match(/https:\/\/example.com\/actors\/alice/)
        end
      end

      context "and a mentions term for a different actor" do
        let_build(:feed, params: JSON.parse(%({"mentions": {"any": ["bob@example.com"]}})).as_h)

        it "does not include the object" do
          expect(judgment.included).to be_false
        end
      end
    end

    context "given a mentions all group" do
      let_build(:feed, params: JSON.parse(%({"mentions": {"all": ["alice@example.com", "bob@example.com"]}})).as_h)
      let_create!(:object, content: "<p>plain</p>")
      let_create!(:mention, subject: object, name: "alice@example.com", href: "https://example.com/actors/alice")

      it "does not include an object mentioning only one" do
        expect(judgment.included).to be_false
      end

      context "and the object carries all mentions" do
        let_create!(:mention, named: bob_mention, subject: object, name: "bob@example.com", href: "https://example.com/actors/bob")

        it "includes the object" do
          expect(judgment.included).to be_true
        end
      end
    end

    context "given a keyword any match and a mention none" do
      let_build(:feed, params: JSON.parse(%({"keywords": {"any": ["alpha"]}, "mentions": {"none": ["alice@example.com"]}})).as_h)
      let_build(:feed, named: without_none, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
      let_create!(:object, content: "<p>alpha</p>")
      let_create!(:mention, subject: object, name: "alice@example.com", href: "https://example.com/actors/alice")

      pre_condition { expect(subject.judge(without_none, [object]).first.included).to be_true }

      it "does not include the object" do
        expect(judgment.included).to be_false
      end

      it "names the excluded handle in the reason" do
        expect(judgment.reason).to match(/alice@example.com/)
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
      expect(subject.validate_params(params)).to contain("Add at least one keyword, #hashtag, or @mention.")
    end

    it "rejects a group with only empty positive lists" do
      params = JSON.parse(%({"keywords": {"any": []}})).as_h
      expect(subject.validate_params(params)).to contain("Add at least one keyword, #hashtag, or @mention.")
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
      params = JSON.parse(%({"hashtags": {"any": ["3dprinting"], "most": ["filament"]}})).as_h
      expect(subject.validate_params(params)).to contain("hashtags has unknown selectors: most")
    end

    it "rejects a hashtags array" do
      params = JSON.parse(%({"hashtags": ["3dprinting"]})).as_h
      expect(subject.validate_params(params)).to contain("hashtags must be an object with any, all, or none")
    end

    it "rejects params with no positive terms across groups" do
      params = JSON.parse(%({"hashtags": {"none": ["spoiler"]}})).as_h
      expect(subject.validate_params(params)).to contain("Add at least one keyword, #hashtag, or @mention.")
    end

    it "accepts a mentions group" do
      params = JSON.parse(%({"mentions": {"any": ["alice@example.com"]}})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    it "accepts keywords, hashtags, and mentions together" do
      params = JSON.parse(%({"keywords": {"any": ["alpha"]}, "hashtags": {"none": ["spoiler"]}, "mentions": {"none": ["alice@example.com"]}})).as_h
      expect(subject.validate_params(params)).to be_empty
    end

    # NOTE: terms below are the *stored form* (after `classify` strips the sigil)

    context "given a hashtag" do
      it "quotes an empty hashtag and names the fix" do
        expect(subject.validate_params(one("hashtags", "any", ""))).to contain(%(Remove the stray "#". It can't be used as a keyword.))
      end

      it "quotes an embedded '#' and names the fix" do
        expect(subject.validate_params(one("hashtags", "any", "cnc #resin"))).to contain(%("#cnc #resin" isn't a single hashtag. Put each "#tag" on its own line, or drop the "#" to match it as a keyword.))
      end

      it "rejects terms that can never match a name" do
        {"" => "stray", "   " => "stray", "##" => "stray", "cnc #resin" => "single hashtag", "cnc,#resin" => "single hashtag"}.each do |term, fragment|
          errors = subject.validate_params(one("hashtags", "any", term))
          expect(errors.join(" ")).to contain(fragment), "expected hashtag #{term.inspect} to be rejected (#{fragment})"
        end
      end

      it "accepts terms that can match a name" do
        [" resin", "3d print", "#cnc", "wood"].each do |term|
          expect(subject.validate_params(one("hashtags", "any", term))).to be_empty, "expected hashtag #{term.inspect} to be accepted"
        end
      end
    end

    context "given a mention handle" do
      it "quotes an empty mention and names the fix" do
        expect(subject.validate_params(one("mentions", "any", ""))).to contain(%(Remove the stray "@". It can't be used as a keyword.))
      end

      it "quotes a mention with a blank host and names the fix" do
        expect(subject.validate_params(one("mentions", "any", "bob@"))).to contain(%("@bob@" is missing a domain. Mentions look like @user@host.com.))
      end

      it "quotes a mention with more than one '@' and names the fix" do
        expect(subject.validate_params(one("mentions", "any", "a@h@x"))).to contain(%("@a@h@x" isn't a single mention. Put each @user@host.com on its own line, or drop the "@" to match it as a keyword.))
      end

      it "rejects terms that can never match a name" do
        {"" => "stray", "   " => "stray", "bob@" => "missing a domain", "bob@   " => "missing a domain", "bob@h@x" => "single mention"}.each do |term, fragment|
          errors = subject.validate_params(one("mentions", "any", term))
          expect(errors.join(" ")).to contain(fragment), "expected handle #{term.inspect} to be rejected (#{fragment})"
        end
      end

      it "accepts terms that can match a name" do
        [" bob@host", "bob smith@h", "bob", "@bob", "bob@host"].each do |term|
          expect(subject.validate_params(one("mentions", "any", term))).to be_empty, "expected handle #{term.inspect} to be accepted"
        end
      end
    end

    context "given a mention URL" do
      it "quotes an invalid link and names the fix" do
        expect(subject.validate_params(one("mentions", "any", "https://"))).to contain(%("https://" isn't a valid link.))
      end

      it "rejects terms that can never match an href" do
        ["https://", "http://", "https:///path", "https:// example.com/a", "https://example.com /a", "https://example.com\t/a", "https://x:abc", "https://x:9999999999999999999"].each do |term|
          errors = subject.validate_params(one("mentions", "any", term))
          expect(errors.join(" ")).to contain("valid link"), "expected URL #{term.inspect} to be rejected"
        end
      end

      it "accepts terms that can match an href" do
        expect(subject.validate_params(one("mentions", "any", "https://example.com/actors/bob"))).to be_empty
      end
    end

    context "given a keyword" do
      it "never rejects a keyword however unusual" do
        ["3d printing", "bob@host", "htp://example.com"].each do |term|
          expect(subject.validate_params(one("keywords", "any", term))).to be_empty, "expected keyword #{term.inspect} to be accepted"
        end
      end
    end
  end

  describe ".iri_term?" do
    it "is true for an http IRI" do
      expect(described_class.iri_term?("http://example.com/actors/bob")).to be_true
    end

    it "is true for an https IRI" do
      expect(described_class.iri_term?("https://example.com/actors/bob")).to be_true
    end

    it "is true case-insensitively" do
      expect(described_class.iri_term?("HTTP://example.com")).to be_true
    end

    it "is false for a handle" do
      expect(described_class.iri_term?("@bob@example.com")).to be_false
    end
  end
end
