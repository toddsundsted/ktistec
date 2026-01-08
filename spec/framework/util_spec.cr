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
      expect(described_class.sanitize(content)).to eq("<a href='https://remote/index.html' target='_blank' rel='external ugc'>a link</a>")
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
        {14.minutes, "14 minutes"},
        {45.minutes, "about 1 hour"},
        {75.minutes, "about 1 hour"},
        {95.minutes, "about 2 hours"},
        {14.hours, "14 hours"},
        {30.hours, "about 1 day"},
        {40.hours, "about 2 days"},
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
end

Spectator.describe Ktistec::Util::PaginatedArray do
  subject { Ktistec::Util::PaginatedArray{0, 1, 2, 3, 4, 5, 6, 7, 8, 9} }

  describe ".more" do
    it "changes the indicator" do
      expect { subject.more = true }.to change { subject.more? }
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
      expect(subject.map(&.-).more?).to eq(false)
    end
  end
end
