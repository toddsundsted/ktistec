require "../../src/framework/util"

require "../spec_helper/base"

Spectator.describe Ktistec::Util do
  describe ".id" do
    it "generates a random identifier" do
      expect(described_class.id).to match(/[a-zA-Z0-9_-]{8}/)
    end
  end

  describe ".sanitize" do
    it "ignores empty content" do
      expect(described_class.sanitize("")).to eq("")
    end

    it "removes forbidden tags and their content entirely" do
      content = "<script>this is a script</script>"
      expect(described_class.sanitize(content)).to eq("")
    end

    it "replaces unsupported tags with their content" do
      content = "<body>this is the body</body>"
      expect(described_class.sanitize(content)).to eq("this is the body")
    end

    it "preserves supported tags" do
      content = "<p>this is <span><strong>some</strong> <em>text</em></span></p>"
      expect(described_class.sanitize(content)).to eq(content)
    end

    it "strips attributes" do
      content = "<span id ='1' class='foo bar'>some text</span>"
      expect(described_class.sanitize(content)).to eq("<span>some text</span>")
    end

    it "preserves href on links, adds target and ugc attribute values to remote links" do
      content = "<a class='foo bar' href='https://remote/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq("<a href='https://remote/index.html' target='_blank' rel='ugc'>a link</a>")
    end

    it "preserves href on local links" do
      content = "<a class='foo bar' href='https://test.test/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq("<a href='https://test.test/index.html'>a link</a>")
    end

    it "preserves href on paths" do
      content = "<a class='foo bar' href='/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq("<a href='/index.html'>a link</a>")
    end

    it "preserves src and alt on images, adds compatibility classes" do
      content = "<img src='https://test.test/pic.jpg' alt='picture'>"
      expect(described_class.sanitize(content)).to eq("<img src='https://test.test/pic.jpg' alt='picture' class='ui image'>")
    end

    it "doesn't corrupt element order" do
      content = "<figure></figure><p></p>"
      expect(described_class.sanitize(content)).to eq("<figure></figure><p></p>")
    end

    it "leaves bare text alone" do
      content = "some text"
      expect(described_class.sanitize(content)).to eq("some text")
    end

    it "leaves escaped content alone" do
      content = "&lt;foo&gt;"
      expect(described_class.sanitize(content)).to eq("&lt;foo&gt;")
    end
  end

  describe "pluralize" do
    sample ["fox", "fish", "dress", "bus", "inch", "fez"] do |noun|
      it "pluralizes the noun" do
        expect(described_class.pluralize(noun)).to eq("#{noun}es")
      end
    end

    it "pluralizes the noun" do
      expect(described_class.pluralize("lady")).to eq("ladies")
    end

    it "pluralizes the noun" do
      expect(described_class.pluralize("boy")).to eq("boys")
    end

    it "pluralizes the noun" do
      expect(described_class.pluralize("dog")).to eq("dogs")
    end
  end
end

Spectator.describe Ktistec::Util::PaginatedArray do
  subject { Ktistec::Util::PaginatedArray{0, 1, 2, 3, 4, 5, 6, 7, 8, 9} }

  describe ".more" do
    it "changes the indicator" do
      expect{subject.more = true}.to change{subject.more?}
    end
  end
end
