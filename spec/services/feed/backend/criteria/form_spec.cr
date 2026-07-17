require "../../../../../src/services/feed/backend/criteria/form"

require "../../../../spec_helper/base"

Spectator.describe Feed::Backend::Criteria::Form do
  def params(json : String) : Hash(String, JSON::Any)
    JSON.parse(json).as_h
  end

  describe ".parse" do
    it "returns empty params for empty buckets" do
      expect(described_class.parse(any: "", all: "", none: "")).to be_empty
    end

    it "infers a keyword from a bare term" do
      expect(described_class.parse(any: "llm", all: "", none: "")).to eq(params(%({"keywords":{"any":["llm"]}})))
    end

    it "infers a hashtag and strips one leading '#'" do
      expect(described_class.parse(any: "#ai", all: "", none: "")).to eq(params(%({"hashtags":{"any":["ai"]}})))
    end

    it "infers a mention handle and strips one leading '@'" do
      expect(described_class.parse(any: "@bob@host", all: "", none: "")).to eq(params(%({"mentions":{"any":["bob@host"]}})))
    end

    it "infers a mention from an IRI" do
      expect(described_class.parse(any: "https://x/bob", all: "", none: "")).to eq(params(%({"mentions":{"any":["https://x/bob"]}})))
    end

    it "infers a mention from an IRI" do
      expect(described_class.parse(any: "HTTPS://x/bob", all: "", none: "")).to eq(params(%({"mentions":{"any":["HTTPS://x/bob"]}})))
    end

    it "strips only one leading '#'" do
      expect(described_class.parse(any: "##tag", all: "", none: "")).to eq(params(%({"hashtags":{"any":["#tag"]}})))
    end

    it "strips only one leading '@'" do
      expect(described_class.parse(any: "@@bob@host", all: "", none: "")).to eq(params(%({"mentions":{"any":["@bob@host"]}})))
    end

    it "routes each to its selector" do
      expect(described_class.parse(any: "a", all: "b", none: "c")).to eq(params(%({"keywords":{"any":["a"],"all":["b"],"none":["c"]}})))
    end

    it "distributes interleaved types" do
      expect(described_class.parse(any: "llm\n#ai\n@bob@host", all: "", none: "")).to eq(params(%({"keywords":{"any":["llm"]},"hashtags":{"any":["ai"]},"mentions":{"any":["bob@host"]}})))
    end

    it "drops whitespace-only lines" do
      expect(described_class.parse(any: "a\n\n   \n\t\nb", all: "", none: "")).to eq(params(%({"keywords":{"any":["a","b"]}})))
    end

    it "normalizes CRLF to LF" do
      expect(described_class.parse(any: "a\r\nb", all: "", none: "")).to eq(params(%({"keywords":{"any":["a","b"]}})))
    end

    it "keeps a leading-space term as a keyword" do
      expect(described_class.parse(any: " llm", all: "", none: "")).to eq(params(%({"keywords":{"any":[" llm"]}})))
    end

    it "keeps a leading-space term as a keyword" do
      expect(described_class.parse(any: "  #tag", all: "", none: "")).to eq(params(%({"keywords":{"any":["  #tag"]}})))
    end

    it "keeps a leading-space term as a keyword" do
      expect(described_class.parse(any: "  @bob@host", all: "", none: "")).to eq(params(%({"keywords":{"any":["  @bob@host"]}})))
    end
  end

  describe ".format" do
    it "returns empty buckets for empty params" do
      expect(described_class.format(params("{}"))).to eq({any: "", all: "", none: ""})
    end

    it "emits a keyword with no sigil" do
      expect(described_class.format(params(%({"keywords":{"any":["llm"]}})))).to eq({any: "llm", all: "", none: ""})
    end

    it "prefixes a hashtag with '#'" do
      expect(described_class.format(params(%({"hashtags":{"any":["ai"]}})))).to eq({any: "#ai", all: "", none: ""})
    end

    it "prefixes a mention handle with '@'" do
      expect(described_class.format(params(%({"mentions":{"any":["bob@host"]}})))).to eq({any: "@bob@host", all: "", none: ""})
    end

    it "leaves a mention IRI bare" do
      expect(described_class.format(params(%({"mentions":{"any":["https://x/bob"]}})))).to eq({any: "https://x/bob", all: "", none: ""})
    end

    it "groups a bucket's terms by type" do
      expect(described_class.format(params(%({"keywords":{"any":["llm"]},"hashtags":{"any":["ai"]},"mentions":{"any":["bob@host"]}})))).to eq({any: "llm\n#ai\n@bob@host", all: "", none: ""})
    end

    it "preserves a leading-space keyword" do
      expect(described_class.format(params(%({"keywords":{"any":[" llm"]}})))[:any]).to eq(" llm")
    end
  end

  context "round trip" do
    it "parse(format(params)) is identity" do
      original = params(%({"keywords":{"any":[" llm","crystal"],"none":["spam"]},"hashtags":{"all":["ai"]},"mentions":{"any":["bob@host","https://x/bob"]}}))
      buckets = described_class.format(original)
      expect(described_class.parse(**buckets)).to eq(original)
    end
  end

  describe ".summarize" do
    it "counts zero terms for empty params" do
      expect(described_class.summarize(params("{}")).count).to eq(0)
    end

    it "counts every term across groups and selectors" do
      summary = described_class.summarize(params(%({"keywords":{"any":["a","b"],"none":["c"]},"hashtags":{"all":["d"]}})))
      expect(summary.count).to eq(4)
    end

    it "projects typed chips" do
      summary = described_class.summarize(params(%({"keywords":{"any":["llm"]},"hashtags":{"any":["ai"]},"mentions":{"none":["bob@host"]}})))
      expect(summary.any).to eq([Feed::Backend::Criteria::Form::Chip.new("keyword", "llm"), Feed::Backend::Criteria::Form::Chip.new("hashtag", "ai")])
    end

    it "projects none-selector chips" do
      summary = described_class.summarize(params(%({"mentions":{"none":["bob@host"]}})))
      expect(summary.none).to eq([Feed::Backend::Criteria::Form::Chip.new("mention", "bob@host")])
    end
  end
end

Spectator.describe Feed::Backend::Criteria::Form::Chip do
  describe "#label" do
    it "leaves a keyword bare" do
      expect(described_class.new("keyword", "llm").label).to eq("llm")
    end

    it "prefixes a hashtag with '#'" do
      expect(described_class.new("hashtag", "ai").label).to eq("#ai")
    end

    it "prefixes a handle mention with '@'" do
      expect(described_class.new("mention", "bob@host").label).to eq("@bob@host")
    end

    it "leaves an IRI mention verbatim" do
      expect(described_class.new("mention", "https://x/bob").label).to eq("https://x/bob")
    end
  end
end
