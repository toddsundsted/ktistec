require "../../src/utils/html"

require "../spec_helper/model"
require "../spec_helper/factory"

Spectator.describe Ktistec::HTML do
  setup_spec

  describe ".enhance" do
    it "returns enhancements" do
      expect(described_class.enhance("")).to be_a(Ktistec::HTML::Enhancements)
    end

    it "returns attachments for embedded images" do
      content = %q|<figure data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
      expect(described_class.enhance(content).attachments).to eq([Ktistec::HTML::Attachment.new("https://test.test/img.png", "image/png")])
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

    it "preserves lone br" do
      content = %q|<div>one<br>two</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p>one<br>two</p>|)
    end

    it "removes trailing br" do
      content = %q|<div><em>one</em><br></div><div>two</div>|
      expect(described_class.enhance(content).content).to eq(%q|<p><em>one</em></p><p>two</p>|)
    end

    it "replaces double br with p" do
      content = %q|<div>one<br><br>two</div>|
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
      expect(described_class.enhance(content).content).to eq(%q|<h1>a</h1><p>b<br>c</p>|)
    end

    it "handles block elements correctly" do
      content = %q|<h1>a</h1><div>b<br><br>c</div>|
      expect(described_class.enhance(content).content).to eq(%q|<h1>a</h1><p>b</p><p>c</p>|)
    end

    it "handles block elements correctly" do
      content = %q|<ul><li>one</li><li>two</li></ul><div><br></div>|
      expect(described_class.enhance(content).content).to eq(%q|<ul><li>one</li><li>two</li></ul>|)
    end

    it "handles block elements correctly" do
      content = %q|<ul><li>one</li><li>two</li></ul><div><br><br></div>|
      expect(described_class.enhance(content).content).to eq(%q|<ul><li>one</li><li>two</li></ul>|)
    end

    it "handles block elements correctly" do
      content = %q|<div><br></div><ul><li>one</li><li>two</li></ul>|
      expect(described_class.enhance(content).content).to eq(%q|<ul><li>one</li><li>two</li></ul>|)
    end

    it "handles block elements correctly" do
      content = %q|<div><br><br></div><ul><li>one</li><li>two</li></ul>|
      expect(described_class.enhance(content).content).to eq(%q|<ul><li>one</li><li>two</li></ul>|)
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

    it "trims empty p" do
      content = %q|<div><figure></figure></div>|
      expect(described_class.enhance(content).content).to eq(%q|<figure></figure>|)
    end

    context "hashtags" do
      it "replaces hashtags with markup" do
        content = %q|<div>#hashtag</div>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{Ktistec.host}/tags/hashtag" class="hashtag" rel="tag">#hashtag</a></p>|)
      end

      it "preserves adjacent text" do
        content = %q|<div> #hashtag </div>|
        expect(described_class.enhance(content).content).to eq(%Q|<p> <a href="#{Ktistec.host}/tags/hashtag" class="hashtag" rel="tag">#hashtag</a> </p>|)
      end

      it "skips hashtags inside links" do
        content = %q|<a href="#">#hashtag</a>|
        expect(described_class.enhance(content).content).to eq(%q|<a href="#">#hashtag</a>|)
      end

      it "returns hashtags" do
        content = %q|<div>#hashtag</div>|
        expect(described_class.enhance(content).hashtags).
          to eq([Ktistec::HTML::Hashtag.new(name: "hashtag", href: "#{Ktistec.host}/tags/hashtag")])
      end
    end

    context "mentions" do
      let_create!(
        :actor,
        iri: "https://bar.com/actors/foo",
        username: "foo",
        urls: ["https://bar.com/@foo"]
      )

      it "replaces matched mentions with links" do
        content = %q|<div>@foo@bar.com</div>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><a href="https://bar.com/actors/foo" class="mention" rel="tag">@foo</a></p>|)
      end

      it "replaces unmatched mentions with spans" do
        content = %q|<div>@bar@foo.com</div>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><span class="mention">@bar@foo.com</span></p>|)
      end

      it "preserves adjacent text" do
        content = %q|<div> @foo@bar.com </div>|
        expect(described_class.enhance(content).content).to eq(%Q|<p> <a href="https://bar.com/actors/foo" class="mention" rel="tag">@foo</a> </p>|)
      end

      it "skips mentions inside links" do
        content = %q|<a href="#">@foo@bar.com</a>|
        expect(described_class.enhance(content).content).to eq(%Q|<a href="#">@foo@bar.com</a>|)
      end

      it "returns mentions" do
        content = %q|<div>@foo@bar.com</div>|
        expect(described_class.enhance(content).mentions).
          to eq([Ktistec::HTML::Mention.new(name: "foo@bar.com", href: "https://bar.com/actors/foo")])
      end
    end

    it "handles both hashtags and mentions" do
      content = %q|<div>#hashtag @bar@foo.com</div>|
      expect(described_class.enhance(content).content).
        to eq(%Q|<p><a href="#{Ktistec.host}/tags/hashtag" class="hashtag" rel="tag">#hashtag</a> <span class="mention">@bar@foo.com</span></p>|)
    end
  end
end
