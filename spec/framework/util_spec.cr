require "../spec_helper"

Spectator.describe Ktistec::Util do
  describe ".enhance" do
    alias Attachment = ActivityPub::Object::Attachment

    it "returns enhancements" do
      expect(described_class.enhance("")).to be_a(Ktistec::Util::Enhancements)
    end

    it "returns attachments for embedded images" do
      content = %q|<figure data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
      expect(described_class.enhance(content).attachments).to eq([Attachment.new("https://test.test/img.png", "image/png")])
    end

    it "strips attributes from the figure" do
      content = %q|<figure data-trix-content-type="" data-trix-attributes=""></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure></figure>|)
    end

    it "strips attributes from the figcaption" do
      content = %q|<figure><figcaption id="" class="">the caption</figcaption></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure><figcaption>the caption</figcaption></figure>|)
    end

    it "removes the anchor but preserves the img and figcaption" do
      content = %q|<figure data-trix-content-type=""><a href=""><img src=""><figcaption></figcaption></a></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure><img src=""><figcaption></figcaption></figure>|)
    end

    it "replaces br with p" do
      content = %q|<div>one<br>two</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>one</p><p>two</p>|)
    end

    it "handles inline elements correctly" do
      content = %q|<div>a <strong>b</strong> c</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a <strong>b</strong> c</p>|)
    end

    it "handles inline elements correctly" do
      content = %q|<div>a <em>b</em> c</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a <em>b</em> c</p>|)
    end

    it "handles inline elements correctly" do
      content = %q|<div>a <del>b</del> c</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a <del>b</del> c</p>|)
    end

    it "handles inline elements correctly" do
      content = %q|<div>a <a href="#">b</a> c</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a <a href="#">b</a> c</p>|)
    end

    it "handles block elements correctly" do
      content = %q|<h1>a</h1><div>b<br>c</div>|
      expect(described_class.enhance(content).content).to eq(%q|<h1>a</h1><p>b</p><p>c</p>|)
    end

    it "handles block elements correctly" do
      content = %q|<div>a</div><blockquote>b<br>c</blockquote>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a</p><blockquote>b<br>c</blockquote>|)
    end

    it "handles block elements correctly" do
      content = %q|<div>a</div><pre>b\nc</pre>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a</p><pre>b\nc</pre>|)
    end

    it "handles block elements correctly" do
      content = %q|<div>a</div><ul><li>b</li><li>c</li></ul>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a</p><ul><li>b</li><li>c</li></ul>|)
    end

    it "handles block elements correctly" do
      content = %q|<div>a</div><ol><li>b</li><li>c</li></ol>|
      expect(described_class.enhance(content).content).to eq(%q|<p>a</p><ol><li>b</li><li>c</li></ol>|)
    end

    it "handles Trix figure elements correctly" do
      content = %q|<div>one<figure></figure>two</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>one</p><figure></figure><p>two</p>|)
    end

    it "preserves adjacent elements" do
      content = %q|<h1>one</h1><h1>two</h1>|
      expect(described_class.enhance(content).content).to eq(%q|<h1>one</h1><h1>two</h1>|)
    end

    it "preserves text" do
      content = %q|this is a test|
      expect(described_class.enhance(content).content).to eq(%q|this is a test|)
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

    it "preserves href on links, adds ugc attribute value" do
      content = "<a href='https://test.test/index.html' rel='ugc'>a link</a>"
      expect(described_class.sanitize(content)).to eq(content)
    end

    it "preserves src and alt on images, adds compatibility classes" do
      content = "<img src='https://test.test/pic.jpg' alt='picture'>"
      expect(described_class.sanitize(content)).to eq("<img src='https://test.test/pic.jpg' alt='picture' class='ui image'>")
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
      expect{described_class.open("https://external/returns-500")}.to raise_error(Ktistec::Util::OpenError)
    end
  end

  describe ".open?" do
    it "returns nil on errors" do
      expect{described_class.open?("https://external/returns-500")}.to be_nil
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
