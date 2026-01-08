require "../../src/utils/html"

require "../spec_helper/base"
require "../spec_helper/network"
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

    context "alt text" do
      it "extracts alt text from data-trix-attachment" do
        content = %q|<figure data-trix-attachment='{"contentType":"image/png","url":"https://test.test/img.png","alt":"A beautiful sunset!"}' data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).attachments).to eq([Ktistec::HTML::Attachment.new("https://test.test/img.png", "image/png", "A beautiful sunset!")])
      end

      it "adds alt attribute to img tag" do
        content = %q|<figure data-trix-attachment='{"contentType":"image/png","url":"https://test.test/img.png","alt":"A beautiful sunset!"}' data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).content).to match(/<img src="https:\/\/test.test\/img.png" alt="A beautiful sunset!">/)
      end

      it "handles attachments without alt text" do
        content = %q|<figure data-trix-attachment='{"contentType":"image/png","url":"https://test.test/img.png"}' data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).attachments).to eq([Ktistec::HTML::Attachment.new("https://test.test/img.png", "image/png")])
      end

      it "handles attachments without alt text" do
        content = %q|<figure data-trix-attachment='{"contentType":"image/png","url":"https://test.test/img.png"}' data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).content).to match(/<img src="https:\/\/test.test\/img.png">/)
      end

      it "handles missing data-trix-attachment attribute" do
        content = %q|<figure data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).attachments).to eq([Ktistec::HTML::Attachment.new("https://test.test/img.png", "image/png")])
      end

      it "handles missing data-trix-attachment attribute" do
        content = %q|<figure data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).content).to match(/<img src="https:\/\/test.test\/img.png">/)
      end

      it "handles malformed JSON" do
        content = %q|<figure data-trix-attachment='[]' data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).attachments).to eq([Ktistec::HTML::Attachment.new("https://test.test/img.png", "image/png")])
      end

      it "handles malformed JSON" do
        content = %q|<figure data-trix-attachment='[]' data-trix-content-type="image/png"><img src="https://test.test/img.png"></figure>|
        expect(described_class.enhance(content).content).to match(/<img src="https:\/\/test.test\/img.png">/)
      end
    end

    it "strips attributes from the figure" do
      content = %q|<figure data-trix-content-type="" data-trix-attributes=""></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure></figure>|)
    end

    it "strips attributes from the figcaption" do
      content = %q|<figure><figcaption id="" class="">the caption</figcaption></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure><figcaption>the caption</figcaption></figure>|)
    end

    it "removes blank figcaption" do
      content = %q|<figure data-trix-content-type="image/png"><img src="https://test.test/img.png"><figcaption></figcaption></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure><img src="https://test.test/img.png"></figure>|)
    end

    it "removes the anchor and empty figcaption, preserves the img" do
      content = %q|<figure data-trix-content-type=""><a href=""><img src=""><figcaption></figcaption></a></figure>|
      expect(described_class.enhance(content).content).to eq(%q|<figure><img src=""></figure>|)
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

      it "skips hashtags inside pre blocks" do
        content = %q|<pre>#hashtag</pre>|
        expect(described_class.enhance(content).content).to eq(%q|<pre>#hashtag</pre>|)
      end

      it "skips hashtags inside code blocks" do
        content = %q|<code>#hashtag</code>|
        expect(described_class.enhance(content).content).to eq(%q|<code>#hashtag</code>|)
      end

      it "returns hashtags" do
        content = %q|<div>#hashtag</div>|
        expect(described_class.enhance(content).hashtags)
          .to eq([Ktistec::HTML::Hashtag.new(name: "hashtag", href: "#{Ktistec.host}/tags/hashtag")])
      end

      context "given full-width hash sign" do
        it "replaces hashtags with markup" do
          content = %q|<div>＃日本語</div>|
          expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{Ktistec.host}/tags/%E6%97%A5%E6%9C%AC%E8%AA%9E" class="hashtag" rel="tag">＃日本語</a></p>|)
        end

        it "handles mixed hash and full-width hash signs" do
          content = %q|<div>#regular ＃fullwidth</div>|
          expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{Ktistec.host}/tags/regular" class="hashtag" rel="tag">#regular</a> <a href="#{Ktistec.host}/tags/fullwidth" class="hashtag" rel="tag">＃fullwidth</a></p>|)
        end

        it "returns hashtags" do
          content = %q|<div>＃モノクロ写真</div>|
          expect(described_class.enhance(content).hashtags)
            .to eq([Ktistec::HTML::Hashtag.new(name: "モノクロ写真", href: "#{Ktistec.host}/tags/モノクロ写真")])
        end
      end
    end

    context "mentions" do
      let_create!(
        :actor,
        iri: "https://bar.com/actors/foo",
        username: "foo",
        urls: ["https://bar.com/@foo"]
      )

      it "replaces mentions with links" do
        content = %q|<div>@foo@bar.com</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p><a href="https://bar.com/actors/foo" class="mention" rel="tag">@foo</a></p>|)
      end

      it "preserves adjacent text" do
        content = %q|<div> @foo@bar.com </div>|
        expect(described_class.enhance(content).content).to eq(%q|<p> <a href="https://bar.com/actors/foo" class="mention" rel="tag">@foo</a> </p>|)
      end

      it "skips mentions inside links" do
        content = %q|<a href="#">@foo@bar.com</a>|
        expect(described_class.enhance(content).content).to eq(%q|<a href="#">@foo@bar.com</a>|)
      end

      it "skips mentions inside pre blocks" do
        content = %q|<pre>@foo@bar.com</pre>|
        expect(described_class.enhance(content).content).to eq(%q|<pre>@foo@bar.com</pre>|)
      end

      it "skips mentions inside code blocks" do
        content = %q|<code>@foo@bar.com</code>|
        expect(described_class.enhance(content).content).to eq(%q|<code>@foo@bar.com</code>|)
      end

      it "returns mentions" do
        content = %q|<div>@foo@bar.com</div>|
        expect(described_class.enhance(content).mentions)
          .to eq([Ktistec::HTML::Mention.new(name: "foo@bar.com", href: "https://bar.com/actors/foo")])
      end

      context "given a mention of an uncached actor" do
        pre_condition { expect(ActivityPub::Actor.find?("https://remote/actors/name")).to be_nil }

        it "replaces mentions with links" do
          content = %q|<div>@foobar@remote</div>|
          expect(described_class.enhance(content).content).to eq(%q|<p><a href="https://remote/actors/foobar" class="mention" rel="tag">@foobar@remote</a></p>|)
        end

        it "returns mentions" do
          content = %q|<div>@foobar@remote</div>|
          expect(described_class.enhance(content).mentions)
            .to eq([Ktistec::HTML::Mention.new(name: "foobar@remote", href: "https://remote/actors/foobar")])
        end
      end

      context "given a mention of a nonexistent actor" do
        it "replaces unmatched mentions with spans" do
          content = %q|<div>@no-such-name@no-such-host.com</div>|
          expect(described_class.enhance(content).content).to eq(%q|<p><span class="mention">@no-such-name@no-such-host.com</span></p>|)
        end

        it "doesn't return mentions" do
          content = %q|<div>@no-such-name@no-such-host.com</div>|
          expect(described_class.enhance(content).mentions)
            .to be_empty
        end
      end
    end

    it "handles both hashtags and mentions" do
      content = %q|<div>#hashtag @bar@foo.com</div>|
      expect(described_class.enhance(content).content)
        .to eq(%Q|<p><a href="#{Ktistec.host}/tags/hashtag" class="hashtag" rel="tag">#hashtag</a> <a href="https://foo.com/actors/bar" class="mention" rel="tag">@bar@foo.com</a></p>|)
    end

    context "bare URLs" do
      it "converts bare URLs to links" do
        content = %q|<div>http://example.com</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p><a href="http://example.com">http://example.com</a></p>|)
      end

      it "converts bare HTTPS URLs to links" do
        content = %q|<div>https://example.com</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p><a href="https://example.com">https://example.com</a></p>|)
      end

      it "preserves adjacent text" do
        content = %q|<div>check out https://example.com for info</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p>check out <a href="https://example.com">https://example.com</a> for info</p>|)
      end

      it "handles URLs with paths, query strings, and fragments" do
        content = %q|<div>https://example.com/path?query=value#foo-bar</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p><a href="https://example.com/path?query=value#foo-bar">https://example.com/path?query=value#foo-bar</a></p>|)
      end

      it "strips trailing punctuation" do
        content = %q|<div>See https://example.com.</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p>See <a href="https://example.com">https://example.com</a>.</p>|)
      end

      it "handles URLs in parentheses" do
        content = %q|<div>(see https://example.com)</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p>(see <a href="https://example.com">https://example.com</a>)</p>|)
      end

      it "handles multiple URLs in one text node" do
        content = %q|<div>Visit https://foo.com and https://bar.com</div>|
        expect(described_class.enhance(content).content).to eq(%q|<p>Visit <a href="https://foo.com">https://foo.com</a> and <a href="https://bar.com">https://bar.com</a></p>|)
      end

      it "handles URLs mixed with hashtags and mentions" do
        content = %q|<div>Check https://example.com #cool @user@host.com</div>|
        expect(described_class.enhance(content).content).to eq(%Q|<p>Check <a href="https://example.com">https://example.com</a> <a href="#{Ktistec.host}/tags/cool" class="hashtag" rel="tag">#cool</a> <a href="https://host.com/actors/user" class="mention" rel="tag">@user@host.com</a></p>|)
      end

      it "skips URLs in links" do
        content = %q|<a href="https://example.com">https://example.com</a>|
        expect(described_class.enhance(content).content).to eq(%q|<a href="https://example.com">https://example.com</a>|)
      end

      it "skips URLs in pre blocks" do
        content = %q|<pre>https://example.com</pre>|
        expect(described_class.enhance(content).content).to eq(%q|<pre>https://example.com</pre>|)
      end

      it "skips URLs in code blocks" do
        content = %q|<code>https://example.com</code>|
        expect(described_class.enhance(content).content).to eq(%q|<code>https://example.com</code>|)
      end
    end

    context "links to local objects/actors" do
      let_create(:actor, local: true)
      let_create(:object, owner: actor, local: true)

      it "converts relative internal links to relative external links" do
        content = %Q|<p><a href="/remote/objects/#{object.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{URI.parse(object.iri).path}">link</a></p>|)
      end

      it "converts absolute internal links to absolute external links" do
        content = %Q|<p><a href="#{Ktistec.host}/remote/objects/#{object.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{object.iri}">link</a></p>|)
      end

      it "converts relative internal links to relative external links" do
        content = %Q|<p><a href="/remote/actors/#{actor.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{URI.parse(actor.iri).path}">link</a></p>|)
      end

      it "converts absolute internal links to absolute external links" do
        content = %Q|<p><a href="#{Ktistec.host}/remote/actors/#{actor.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(%Q|<p><a href="#{actor.iri}">link</a></p>|)
      end
    end

    context "links to remote objects/actors" do
      let_create(:actor)
      let_create(:object, owner: actor)

      it "does not convert relative internal links" do
        content = %Q|<p><a href="/remote/objects/#{object.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(content)
      end

      it "does not convert absolute internal links" do
        content = %Q|<p><a href="#{Ktistec.host}/remote/objects/#{object.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(content)
      end

      it "does not convert relative internal links" do
        content = %Q|<p><a href="/remote/actors/#{actor.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(content)
      end

      it "does not convert absolute internal links" do
        content = %Q|<p><a href="#{Ktistec.host}/remote/actors/#{actor.id}">link</a></p>|
        expect(described_class.enhance(content).content).to eq(content)
      end
    end
  end
end
