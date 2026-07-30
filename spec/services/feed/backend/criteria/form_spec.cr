require "../../../../../src/services/feed/backend/criteria/form"

require "../../../../spec_helper/base"

Spectator.describe Feed::Backend::Criteria::Form do
  def params(json : String) : Hash(String, JSON::Any)
    JSON.parse(json).as_h
  end

  def parse_groups(any : String, all : String, none : String) : Hash(String, JSON::Any)
    described_class.parse(any: any, all: all, none: none).reject(Feed::Backend::Criteria::ORDER)
  end

  def parse_order(any : String, all : String, none : String) : JSON::Any?
    described_class.parse(any: any, all: all, none: none)[Feed::Backend::Criteria::ORDER]?
  end

  describe ".parse" do
    it "returns empty params for empty buckets" do
      expect(parse_groups(any: "", all: "", none: "")).to be_empty
    end

    it "infers a keyword from a bare term" do
      expect(parse_groups(any: "llm", all: "", none: "")).to eq(params(%({"keywords":{"any":["llm"]}})))
    end

    it "infers a hashtag and strips one leading '#'" do
      expect(parse_groups(any: "#ai", all: "", none: "")).to eq(params(%({"hashtags":{"any":["ai"]}})))
    end

    it "infers a mention handle and strips one leading '@'" do
      expect(parse_groups(any: "@bob@host", all: "", none: "")).to eq(params(%({"mentions":{"any":["bob@host"]}})))
    end

    it "infers a mention from an IRI" do
      expect(parse_groups(any: "https://x/bob", all: "", none: "")).to eq(params(%({"mentions":{"any":["https://x/bob"]}})))
    end

    it "infers a mention from an IRI" do
      expect(parse_groups(any: "HTTPS://x/bob", all: "", none: "")).to eq(params(%({"mentions":{"any":["HTTPS://x/bob"]}})))
    end

    it "strips only one leading '#'" do
      expect(parse_groups(any: "##tag", all: "", none: "")).to eq(params(%({"hashtags":{"any":["#tag"]}})))
    end

    it "strips only one leading '@'" do
      expect(parse_groups(any: "@@bob@host", all: "", none: "")).to eq(params(%({"mentions":{"any":["@bob@host"]}})))
    end

    it "routes each to its selector" do
      expect(parse_groups(any: "a", all: "b", none: "c")).to eq(params(%({"keywords":{"any":["a"],"all":["b"],"none":["c"]}})))
    end

    it "distributes interleaved types" do
      expect(parse_groups(any: "llm\n#ai\n@bob@host", all: "", none: "")).to eq(params(%({"keywords":{"any":["llm"]},"hashtags":{"any":["ai"]},"mentions":{"any":["bob@host"]}})))
    end

    it "drops whitespace-only lines" do
      expect(parse_groups(any: "a\n\n   \n\t\nb", all: "", none: "")).to eq(params(%({"keywords":{"any":["a","b"]}})))
    end

    it "normalizes CRLF to LF" do
      expect(parse_groups(any: "a\r\nb", all: "", none: "")).to eq(params(%({"keywords":{"any":["a","b"]}})))
    end

    it "keeps a leading-space term as a keyword" do
      expect(parse_groups(any: " llm", all: "", none: "")).to eq(params(%({"keywords":{"any":[" llm"]}})))
    end

    it "keeps a leading-space term as a keyword" do
      expect(parse_groups(any: "  #tag", all: "", none: "")).to eq(params(%({"keywords":{"any":["  #tag"]}})))
    end

    it "keeps a leading-space term as a keyword" do
      expect(parse_groups(any: "  @bob@host", all: "", none: "")).to eq(params(%({"keywords":{"any":["  @bob@host"]}})))
    end

    it "records no order for empty buckets" do
      expect(parse_order(any: "", all: "", none: "")).to be_nil
    end

    it "records the order" do
      expect(parse_order(any: "llm\n#ai\n@bob@host", all: "", none: "")).to eq(JSON.parse(%({"any":["llm","#ai","@bob@host"]})))
    end

    it "records the order per selector" do
      expect(parse_order(any: "a", all: "#b", none: "c")).to eq(JSON.parse(%({"any":["a"],"all":["#b"],"none":["c"]})))
    end

    it "records a term's presented form" do
      expect(parse_order(any: "@https://x/bob", all: "", none: "")).to eq(JSON.parse(%({"any":["https://x/bob"]})))
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

    it "preserves a leading-space keyword" do
      expect(described_class.format(params(%({"keywords":{"any":[" llm"]}})))[:any]).to eq(" llm")
    end

    it "groups a bucket's terms by type when no order is recorded" do
      expect(described_class.format(params(%({"keywords":{"any":["llm"]},"hashtags":{"any":["ai"]},"mentions":{"any":["bob@host"]}})))).to eq({any: "llm\n#ai\n@bob@host", all: "", none: ""})
    end

    context "given an order that names every term" do
      it "presents a bucket's terms in that order" do
        expect(described_class.format(params(%({"keywords":{"any":["zeta"]},"hashtags":{"any":["ai"]},"order":{"any":["#ai","zeta"]}})))).to eq({any: "#ai\nzeta", all: "", none: ""})
      end
    end

    context "given an order that omits a term" do
      let(subject) { params(%({"keywords":{"any":["zeta","apple"]},"hashtags":{"any":["ai"]},"order":{"any":["#ai"]}})) }

      it "presents every term" do
        expect(described_class.format(subject)[:any]).to eq("zeta\napple\n#ai")
      end

      it "survives a round trip" do
        expect(parse_groups(**described_class.format(subject))).to eq(subject.reject(Feed::Backend::Criteria::ORDER))
      end
    end

    context "given an order naming a term the groups don't hold" do
      it "falls back to grouping by type" do
        expect(described_class.format(params(%({"keywords":{"any":["zeta"]},"hashtags":{"any":["ai"]},"order":{"any":["#ai","gone","zeta"]}})))[:any]).to eq("zeta\n#ai")
      end
    end

    context "given an order under an unrecognized selector" do
      it "falls back to grouping by type" do
        expect(described_class.format(params(%({"keywords":{"any":["zeta"]},"hashtags":{"any":["ai"]},"order":{"bogus":["x"]}})))[:any]).to eq("zeta\n#ai")
      end
    end
  end

  context "round trip" do
    it "parse(format(params)) is identity over the type groups" do
      original = params(%({"keywords":{"any":[" llm","crystal"],"none":["spam"]},"hashtags":{"all":["ai"]},"mentions":{"any":["bob@host","https://x/bob"]}}))
      expect(parse_groups(**described_class.format(original))).to eq(original)
    end

    it "format(parse(buckets)) preserves the order terms were entered in" do
      text = "zeta\n#ai\napple\n@bob@host"
      expect(described_class.format(described_class.parse(any: text, all: "", none: ""))[:any]).to eq(text)
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

    it "projects typed terms" do
      summary = described_class.summarize(params(%({"keywords":{"any":["llm"]},"hashtags":{"any":["ai"]},"mentions":{"none":["bob@host"]}})))
      expect(summary.any).to eq([Feed::Backend::Criteria::Form::Term.new("keyword", "llm"), Feed::Backend::Criteria::Form::Term.new("hashtag", "ai")])
    end

    it "projects none-selector terms" do
      summary = described_class.summarize(params(%({"mentions":{"none":["bob@host"]}})))
      expect(summary.none).to eq([Feed::Backend::Criteria::Form::Term.new("mention", "bob@host")])
    end

    context "given a recorded order" do
      let(summary) do
        described_class.summarize(params(%({"keywords":{"any":["zeta"]},"hashtags":{"any":["ai"]},"order":{"any":["#ai","zeta"]}})))
      end

      it "projects typed terms in order" do
        expect(summary.any).to eq([Feed::Backend::Criteria::Form::Term.new("hashtag", "ai"), Feed::Backend::Criteria::Form::Term.new("keyword", "zeta")])
      end

      it "counts every term" do
        expect(summary.count).to eq(2)
      end
    end

    context "given an order that omits a term" do
      let(summary) do
        described_class.summarize(params(%({"keywords":{"any":["zeta","apple"]},"hashtags":{"any":["ai"]},"order":{"any":["#ai"]}})))
      end

      it "projects term, grouped by type" do
        expect(summary.any).to eq([Feed::Backend::Criteria::Form::Term.new("keyword", "zeta"), Feed::Backend::Criteria::Form::Term.new("keyword", "apple"), Feed::Backend::Criteria::Form::Term.new("hashtag", "ai")])
      end

      it "counts every term" do
        expect(summary.count).to eq(3)
      end
    end
  end
end

Spectator.describe Feed::Backend::Criteria::Form::Term do
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
