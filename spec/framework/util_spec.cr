require "../../src/framework/util"

require "../spec_helper/base"

Spectator.describe Ktistec::Util do
  describe ".id" do
    it "generates a random identifier" do
      expect(described_class.id).to match(/[a-zA-Z0-9_-]{8}/)
    end
  end

  describe ".render_as_text" do
    it "ignores empty content" do
      expect(described_class.render_as_text("")).to eq("")
    end

    it "removes inline markup" do
      content = "this is <span><strong>some</strong> <em>text</em></span>"
      expect(described_class.render_as_text(content)).to eq("this is some text")
    end

    it "replaces block elements with newlines" do
      content = "<p>foo</p><p>bar</p>"
      expect(described_class.render_as_text(content)).to eq("foo\nbar\n")
    end

    it "leaves bare text alone" do
      content = "some text"
      expect(described_class.render_as_text(content)).to eq("some text")
    end

    it "leaves escaped content alone" do
      content = "&lt;foo&gt;"
      expect(described_class.render_as_text(content)).to eq("&lt;foo&gt;")
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
      content = "<p>this is <span><strong>some</strong> <em>text</em> <sup>test</sup> <sub>test</sub> <del>test</del> <ins>test</ins> <s>test</s></span></p>"
      expect(described_class.sanitize(content)).to eq(content)
    end

    it "strips attributes" do
      content = "<span id ='1' class='foo bar'>some text</span>"
      expect(described_class.sanitize(content)).to eq("<span>some text</span>")
    end

    it "preserves href on links, adds target and rel attributes to remote links" do
      content = "<a class='foo bar' href='https://remote/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq("<a href='https://remote/index.html' target='_blank' rel='external ugc noopener'>a link</a>")
    end

    it "preserves href on links, adds data-turbo-frame attribute to local links" do
      content = "<a class='foo bar' href='https://test.test/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq("<a href='https://test.test/index.html' data-turbo-frame='_top'>a link</a>")
    end

    it "preserves href on paths, adds data-turbo-frame attribute" do
      content = "<a class='foo bar' href='/index.html'>a link</a>"
      expect(described_class.sanitize(content)).to eq("<a href='/index.html' data-turbo-frame='_top'>a link</a>")
    end

    it "preserves 'emoji' in class attribute on img elements" do
      content = "<img class='emoji foo bar' src='https://test.test/emoji.png' alt=':emoji:'>"
      expect(described_class.sanitize(content)).to eq("<img src='https://test.test/emoji.png' alt=':emoji:' class='ui image emoji' loading='lazy'>")
    end

    it "preserves src and alt on images, adds loading attribute and compatibility classes" do
      content = "<img src='https://test.test/pic.jpg' alt='picture'>"
      expect(described_class.sanitize(content)).to eq("<img src='https://test.test/pic.jpg' alt='picture' class='ui image' loading='lazy'>")
    end

    it "preserves src on audio, adds controls attribute and compatibility classes" do
      content = "<audio src='https://test.test/snd.mp3'></audio>"
      expect(described_class.sanitize(content)).to eq("<audio src='https://test.test/snd.mp3' class='ui audio' controls></audio>")
    end

    it "preserves src on video, adds controls attribute and compatibility classes" do
      content = "<video src='https://test.test/vid.mp4'></video>"
      expect(described_class.sanitize(content)).to eq("<video src='https://test.test/vid.mp4' class='ui video' controls></video>")
    end

    # for presentation of mastodon compatible profile metadata
    it "preserves 'invisible' in class attribute on span elements" do
      content = "<span class='invisible foo bar'>a span</span>"
      expect(described_class.sanitize(content)).to eq("<span class='invisible'>a span</span>")
    end

    # for presentation of mastodon compatible profile metadata
    it "preserves 'ellipsis' in class attribute on span elements" do
      content = "<span class='ellipsis foo bar'>a span</span>"
      expect(described_class.sanitize(content)).to eq("<span class='ellipsis'>a span</span>")
    end

    # for quote posts (FEP-044f)
    it "preserves 'quote-inline' in class attribute on span elements" do
      content = "<span class='quote-inline foo'>RE: <a href='https://example.com/status/1'>link</a></span>"
      expect(described_class.sanitize(content)).to eq("<span class='quote-inline'>RE: <a href='https://example.com/status/1' target='_blank' rel='external ugc noopener'>link</a></span>")
    end

    # for quote posts (FEP-044f)
    it "preserves 'quote-inline' in class attribute on p elements" do
      content = "<p class='quote-inline foo'>RE: <a href='https://example.com/status/1'>link</a></p>"
      expect(described_class.sanitize(content)).to eq("<p class='quote-inline'>RE: <a href='https://example.com/status/1' target='_blank' rel='external ugc noopener'>link</a></p>")
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

    it "escapes single quotes in attribute values" do
      content = %Q(<img src="y&apos;onerror=&apos;alert(1)">)
      expect(described_class.sanitize(content)).to eq(
        "<img src='y&#39;onerror=&#39;alert(1)' class='ui image' loading='lazy'>",
      )
    end

    it "escapes ampersands in attribute values" do
      content = %Q(<a href="https://example.com/?a=1&amp;b=2">link</a>)
      expect(described_class.sanitize(content)).to eq(
        "<a href='https://example.com/?a=1&amp;b=2' target='_blank' rel='external ugc noopener'>link</a>",
      )
    end

    it "the sanitized attribute payload does not parse back as a new attribute" do
      content = %Q(<img src="y&apos; onerror=&apos;alert(1)">)
      output = described_class.sanitize(content)
      parsed = XML.parse_html(
        "<div>#{output}</div>",
        XML::HTMLParserOptions::RECOVER | XML::HTMLParserOptions::NODEFDTD | XML::HTMLParserOptions::NOIMPLIED,
      )
      expect(parsed.xpath_nodes("//img/@onerror")).to be_empty
    end

    it "drops href with javascript scheme" do
      content = %Q(<a href="javascript:alert(1)">link</a>)
      expect(described_class.sanitize(content)).to_not match(/href=/)
    end

    it "drops href with data scheme" do
      content = %Q(<a href="data:text/html,&lt;script&gt;alert(1)&lt;/script&gt;">x</a>)
      expect(described_class.sanitize(content)).to_not match(/href=/)
    end

    it "drops href with vbscript scheme" do
      content = %Q(<a href="vbscript:msgbox(1)">x</a>)
      expect(described_class.sanitize(content)).to_not match(/href=/)
    end

    it "preserves mailto href" do
      content = %Q(<a href="mailto:alice@example.com">email</a>)
      expect(described_class.sanitize(content)).to eq(
        "<a href='mailto:alice@example.com' target='_blank' rel='external ugc noopener'>email</a>",
      )
    end

    it "preserves tel href" do
      content = %Q(<a href="tel:+15551234567">call</a>)
      expect(described_class.sanitize(content)).to eq(
        "<a href='tel:+15551234567' target='_blank' rel='external ugc noopener'>call</a>",
      )
    end

    it "drops img src with javascript scheme" do
      content = %Q(<img src="javascript:alert(1)">)
      expect(described_class.sanitize(content)).to_not match(/src=/)
    end
  end

  describe ".safe_url?" do
    it "accepts http" do
      expect(described_class.safe_url?("http://example.com/")).to be_true
    end

    it "accepts https" do
      expect(described_class.safe_url?("https://example.com/")).to be_true
    end

    it "accepts relative paths" do
      expect(described_class.safe_url?("/relative/path")).to be_true
    end

    it "accepts mailto" do
      expect(described_class.safe_url?("mailto:alice@example.com")).to be_true
    end

    it "accepts tel" do
      expect(described_class.safe_url?("tel:+15551234567")).to be_true
    end

    it "accepts magnet" do
      expect(described_class.safe_url?("magnet:?xt=urn:btih:abcdef&dn=example")).to be_true
    end

    it "accepts wss" do
      expect(described_class.safe_url?("wss://tracker.example/socket")).to be_true
    end

    it "accepts at" do
      expect(described_class.safe_url?("at://did:plc:abc/app.bsky.feed.post/123")).to be_true
    end

    it "accepts did" do
      expect(described_class.safe_url?("did:plc:abc")).to be_true
    end

    it "rejects javascript" do
      expect(described_class.safe_url?("javascript:alert(1)")).to be_false
    end

    it "rejects data" do
      expect(described_class.safe_url?("data:text/html,<script>alert(1)</script>")).to be_false
    end

    it "rejects vbscript" do
      expect(described_class.safe_url?("vbscript:msgbox(1)")).to be_false
    end

    it "rejects file" do
      expect(described_class.safe_url?("file:///etc/passwd")).to be_false
    end

    it "is case-insensitive" do
      expect(described_class.safe_url?("JavaScript:alert(1)")).to be_false
      expect(described_class.safe_url?("HTTPS://example.com/")).to be_true
    end

    it "rejects embedded newline in the scheme" do
      expect(described_class.safe_url?("java\nscript:alert(1)")).to be_false
    end

    it "rejects embedded carriage return in the scheme" do
      expect(described_class.safe_url?("java\rscript:alert(1)")).to be_false
    end

    it "rejects embedded tab in the scheme" do
      expect(described_class.safe_url?("java\tscript:alert(1)")).to be_false
    end

    it "rejects embedded space in the scheme" do
      expect(described_class.safe_url?("java script:alert(1)")).to be_false
    end

    it "rejects DEL (0x7f) in the scheme" do
      expect(described_class.safe_url?("java\x7fscript:alert(1)")).to be_false
    end

    it "rejects leading control character" do
      expect(described_class.safe_url?("\x00javascript:alert(1)")).to be_false
    end

    it "rejects leading whitespace" do
      expect(described_class.safe_url?(" https://example.com/")).to be_false
    end

    it "rejects a NUL (0x00) anywhere in the URL" do
      expect(described_class.safe_url?("https://example.com/\x00/path")).to be_false
    end

    it "accepts URLs containing a single quote" do
      expect(described_class.safe_url?("https://example.com/'foo")).to be_true
    end
  end

  describe ".safe_iri?" do
    it "accepts http" do
      expect(described_class.safe_iri?("http://example.com/")).to be_true
    end

    it "accepts https" do
      expect(described_class.safe_iri?("https://example.com/")).to be_true
    end

    it "rejects javascript" do
      expect(described_class.safe_iri?("javascript:alert(1)")).to be_false
    end

    it "rejects data" do
      expect(described_class.safe_iri?("data:text/html,<script>alert(1)</script>")).to be_false
    end

    # schemes that pass `safe_url?` (display contexts) but not `safe_iri?` (identifier contexts)

    it "rejects mailto" do
      expect(described_class.safe_iri?("mailto:alice@example.com")).to be_false
    end

    it "rejects tel" do
      expect(described_class.safe_iri?("tel:+15551234567")).to be_false
    end

    it "rejects magnet" do
      expect(described_class.safe_iri?("magnet:?xt=urn:btih:abc")).to be_false
    end

    it "rejects wss" do
      expect(described_class.safe_iri?("wss://tracker.example/socket")).to be_false
    end

    it "rejects at" do
      expect(described_class.safe_iri?("at://did:plc:abc/app.bsky.feed.post/123")).to be_false
    end

    it "rejects did" do
      expect(described_class.safe_iri?("did:plc:abc")).to be_false
    end

    it "rejects URLs with control characters" do
      expect(described_class.safe_iri?("java\nscript:alert(1)")).to be_false
    end

    it "rejects URLs containing a single quote" do
      expect(described_class.safe_iri?("https://example.com/'foo")).to be_false
    end

    it "rejects URLs containing a double quote" do
      expect(described_class.safe_iri?(%q(https://example.com/"foo))).to be_false
    end

    it "rejects URLs containing a backslash" do
      expect(described_class.safe_iri?(%q(https://example.com/\foo))).to be_false
    end

    it "rejects URLs containing a less-than sign" do
      expect(described_class.safe_iri?("https://example.com/<foo")).to be_false
    end

    it "rejects URLs containing a greater-than sign" do
      expect(described_class.safe_iri?("https://example.com/>foo")).to be_false
    end
  end

  describe ".url_scheme" do
    it "returns the lowercased scheme" do
      expect(described_class.url_scheme("HTTPS://example.com/")).to eq("https")
    end

    it "returns nil" do
      expect(described_class.url_scheme("/path")).to be_nil
    end

    it "returns nil" do
      expect(described_class.url_scheme("")).to be_nil
    end
  end

  describe ".absolute_uri?" do
    it "accepts http" do
      expect(described_class.absolute_uri?("http://example.com/")).to be_true
    end

    it "accepts https" do
      expect(described_class.absolute_uri?("https://example.com/")).to be_true
    end

    it "accepts at" do
      expect(described_class.absolute_uri?("at://did:plc:abc/app.bsky.feed.post/123")).to be_true
    end

    it "rejects relative path" do
      expect(described_class.absolute_uri?("/path")).to be_false
    end

    it "rejects empty string" do
      expect(described_class.absolute_uri?("")).to be_false
    end

    it "rejects URLs with control characters" do
      expect(described_class.absolute_uri?("http\nbad://example.com")).to be_false
    end

    it "rejects URLs containing a double quote" do
      expect(described_class.absolute_uri?(%q(https://example.com/"foo))).to be_false
    end

    it "rejects URLs containing a less-than sign" do
      expect(described_class.absolute_uri?("https://example.com/<foo")).to be_false
    end

    it "rejects URLs containing a greater-than sign" do
      expect(described_class.absolute_uri?("https://example.com/>foo")).to be_false
    end
  end

  describe ".to_sentence" do
    it "returns an empty string" do
      expect(described_class.to_sentence([] of String)).to eq("")
    end

    it "returns the word" do
      expect(described_class.to_sentence(["one"])).to eq("one")
    end

    it "returns the words in sentence form" do
      expect(described_class.to_sentence(["one", "two"])).to eq("one and two")
    end

    it "returns the words in sentence form" do
      expect(described_class.to_sentence(["one", "two", "three"])).to eq("one, two and three")
    end

    it "uses the specified words connector" do
      expect(described_class.to_sentence(["one", "two", "three"], words_connector: " and ")).to eq("one and two and three")
    end

    it "uses the specified last word connector" do
      expect(described_class.to_sentence(["one", "two", "three"], last_word_connector: " or ")).to eq("one, two or three")
    end
  end

  describe ".distance_of_time_in_words" do
    def self.test_pairs
      [
        {14.seconds, "less than a minute"},
        {45.seconds, "1 minute"},
        {75.seconds, "1 minute"},
        {95.seconds, "2 minutes"},
        {13.minutes + 25.seconds, "13 minutes"},
        {13.minutes + 35.seconds, "14 minutes"},
        {14.minutes, "14 minutes"},
        {45.minutes, "about 1 hour"},
        {75.minutes, "about 1 hour"},
        {95.minutes, "about 2 hours"},
        {13.hours + 25.minutes, "13 hours"},
        {13.hours + 35.minutes, "14 hours"},
        {14.hours, "14 hours"},
        {30.hours, "about 1 day"},
        {40.hours, "about 2 days"},
        {13.days + 11.hours, "13 days"},
        {13.days + 13.hours, "14 days"},
        {14.days, "14 days"},
        {40.days, "about 1 month"},
        {50.days, "about 2 months"},
        {10.months, "10 months"},
        {14.months, "about 1 year"},
        {18.months, "over 1 year"},
        {22.months, "almost 2 years"},
        {26.months, "about 2 years"},
        {30.months, "over 2 years"},
        {34.months, "almost 3 years"},
      ]
    end

    let(now) { Time.utc }

    sample test_pairs do |span, words|
      it "transforms the span of time into words" do
        expect(described_class.distance_of_time_in_words(now + span, now)).to eq(words)
      end
    end
  end

  describe ".pluralize" do
    it "pluralizes the noun" do
      ["fox", "fish", "dress", "bus", "inch", "fez"].each do |noun|
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

  describe ".wrap_link" do
    PARSER_OPTIONS = XML::HTMLParserOptions::NOIMPLIED | XML::HTMLParserOptions::NODEFDTD

    let(link) { "https://example.com/this-is-a-url" }

    subject { XML.parse_html(described_class.wrap_link(link), PARSER_OPTIONS) }

    it "wraps the link in an anchor" do
      expect(subject.xpath_nodes("/a/@href")).to contain(link)
    end

    it "wraps the scheme in an invisible span" do
      expect(subject.xpath_nodes("/a/span[contains(@class,'invisible')]/text()")).to contain("https://")
    end

    it "does not include the host and path in an ellipsis span" do
      expect(subject.xpath_nodes("/a/span[not(contains(@class,'ellipsis'))]/text()")).to contain("example.com/this-is-a-url")
    end

    context "given a very long link" do
      let(link) { "https://example.com/this-is-a-very-long-url" }

      it "wraps the truncated host and path in an ellipsis span" do
        expect(subject.xpath_nodes("/a/span[contains(@class,'ellipsis')]/text()")).to contain("example.com/this-is-a-very-lon")
      end

      it "wraps the remainder in an invisible span" do
        expect(subject.xpath_nodes("/a/span[contains(@class,'invisible')]/text()")).to contain("g-url")
      end

      context "with length specified" do
        subject { XML.parse_html(described_class.wrap_link(link, length: 20), PARSER_OPTIONS) }

        it "wraps the truncated host and path in an ellipsis span" do
          expect(subject.xpath_nodes("/a/span[contains(@class,'ellipsis')]/text()")).to contain("example.com/this-is-")
        end

        it "wraps the remainder in an invisible span" do
          expect(subject.xpath_nodes("/a/span[contains(@class,'invisible')]/text()")).to contain("a-very-long-url")
        end
      end
    end

    context "with scheme included" do
      subject { XML.parse_html(described_class.wrap_link(link, include_scheme: true), PARSER_OPTIONS) }

      it "does not wrap the scheme in an invisible span" do
        expect(subject.xpath_nodes("/a/span[contains(@class,'invisible')]/text()")).not_to contain("https://")
      end

      it "includes the scheme with the host and path" do
        expect(subject.xpath_nodes("/a/span/text()")).to contain("https://example.com/this-is-a-")
      end
    end

    context "with tag specified" do
      subject { XML.parse_html(described_class.wrap_link(link, tag: :td), PARSER_OPTIONS) }

      it "wraps the link in the tag" do
        expect(subject.xpath_nodes("/td/span/text()")).to contain_exactly("https://", "example.com/this-is-a-url")
      end
    end

    context "given a string that is not a link" do
      let(link) { "this is a string" }

      it "returns the string" do
        expect(described_class.wrap_link(link)).to eq(link)
      end

      context "with HTML metacharacters" do
        let(link) { %q(<img onerror=x src=x>) }

        it "escapes the string" do
          expect(described_class.wrap_link(link)).to eq("&lt;img onerror=x src=x&gt;")
        end

        it "does not introduce an img element" do
          expect(XML.parse_html(described_class.wrap_link(link), PARSER_OPTIONS).xpath_nodes("//img")).to be_empty
        end
      end
    end

    context "given a link with HTML metacharacters" do
      let(link) { %q(https://evil.example/"><img/onerror=x/src=y>) }

      it "escapes the href attribute" do
        expect(described_class.wrap_link(link)).to contain(%(href="https://evil.example/&quot;&gt;&lt;img/onerror=x/src=y&gt;"))
      end

      it "does not introduce an img element" do
        expect(XML.parse_html(described_class.wrap_link(link), PARSER_OPTIONS).xpath_nodes("//img")).to be_empty
      end

      it "does not introduce an img element" do
        expect(XML.parse_html(described_class.wrap_link(link, tag: :span), PARSER_OPTIONS).xpath_nodes("//img")).to be_empty
      end
    end

    context "given a long link with HTML metacharacters" do
      let(link) { %q(https://evil.example/"><img/onerror=x/src=y>/padding/padding) }

      it "escapes the href attribute" do
        expect(described_class.wrap_link(link)).to contain(%(href="https://evil.example/&quot;&gt;&lt;img/onerror=x/src=y&gt;/padding/padding"))
      end

      it "does not introduce a stray img element" do
        expect(XML.parse_html(described_class.wrap_link(link), PARSER_OPTIONS).xpath_nodes("//img")).to be_empty
      end

      it "does not introduce a stray img element" do
        expect(XML.parse_html(described_class.wrap_link(link, tag: :span), PARSER_OPTIONS).xpath_nodes("//img")).to be_empty
      end
    end

    context "given a link with an unsafe scheme" do
      let(link) { "javascript://example.com/%0Aalert(1)" }

      it "escapes the string" do
        expect(described_class.wrap_link(link)).to eq("javascript://example.com/%0Aalert(1)")
      end

      it "does not produce an anchor" do
        expect(XML.parse_html(described_class.wrap_link(link), PARSER_OPTIONS).xpath_nodes("//a")).to be_empty
      end
    end
  end
end

Spectator.describe Ktistec::Util::PaginatedArray do
  subject { Ktistec::Util::PaginatedArray{0, 1, 2, 3, 4, 5, 6, 7, 8, 9} }

  describe ".more" do
    it "changes the indicator" do
      expect { subject.more = true }.to change { subject.more? }
    end
  end

  describe ".cursor_start" do
    it "is nil" do
      expect(subject.cursor_start).to be_nil
    end

    it "can be set" do
      subject.cursor_start = 100_i64
      expect(subject.cursor_start).to eq(100_i64)
    end
  end

  describe ".cursor_end" do
    it "is nil" do
      expect(subject.cursor_end).to be_nil
    end

    it "can be set" do
      subject.cursor_end = 50_i64
      expect(subject.cursor_end).to eq(50_i64)
    end
  end

  describe "#map" do
    it "returns a paginated array" do
      expect(subject.map(&.-)).to be_a(Ktistec::Util::PaginatedArray(Int32))
    end

    it "returns a paginated array with the results of applying the supplied block" do
      expect(subject.map(&.-)).to eq([0, -1, -2, -3, -4, -5, -6, -7, -8, -9])
    end

    it "returns an indication of whether there are more results" do
      expect(subject.map(&.-).more?).to be_false
    end

    it "preserves cursor_start through map" do
      subject.cursor_start = 100_i64
      expect(subject.map(&.-).cursor_start).to eq(100_i64)
    end

    it "preserves cursor_end through map" do
      subject.cursor_end = 50_i64
      expect(subject.map(&.-).cursor_end).to eq(50_i64)
    end
  end
end
