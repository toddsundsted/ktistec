require "../spec_helper"

Spectator.describe Balloon::Util do
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
      expect(described_class.sanitize(content)).to eq("<p>this is the body</p>")
    end

    it "preserves supported tags" do
      content = "<p>this is <span><strong>some</strong> <em>text</em></span></p>"
      expect(described_class.sanitize(content)).to eq(content)
    end

    it "strips attributes" do
      content = "<span id ='1' class='foo bar'>some text</span>"
      expect(described_class.sanitize(content)).to eq("<span>some text</span>")
    end

    it "preserves href on links" do
      content = "<a href='https://test.test/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq(content)
    end

    it "preserves src and alt on images" do
      content = "<img src='https://test.test/pic.jpg' alt='picture'>"
      expect(described_class.sanitize(content)).to eq(content)
    end

    it "wraps bare text in a tag" do
      content = "some text"
      expect(described_class.sanitize(content)).to eq("<p>some text</p>")
    end
  end

  describe ".open" do
    it "fetches the specified page" do
      expect(described_class.open("https://external/specified-page").body).to eq("content")
    end

    it "follows redirects" do
      expect(described_class.open("https://external/redirected-page").body).to eq("content")
    end

    it "fails on errors" do
      expect{described_class.open("https://external/returns-500")}.to raise_error(Balloon::Util::OpenError)
    end
  end

  describe ".open?" do
    it "returns nil on errors" do
      expect{described_class.open?("https://external/returns-500")}.to be_nil
    end
  end
end

Spectator.describe Balloon::Util::PaginatedArray do
  subject { Balloon::Util::PaginatedArray{0, 1, 2, 3, 4, 5, 6, 7, 8, 9} }

  describe ".more" do
    it "changes the indicator" do
      expect{subject.more = true}.to change{subject.more?}
    end
  end
end
