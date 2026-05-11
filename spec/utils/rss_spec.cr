require "../../src/utils/rss"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Ktistec::RSS do
  setup_spec

  describe ".generate_rss_feed" do
    let(feed_title) { Ktistec.site }
    let(feed_url) { Ktistec.host }
    let(description) { %{Test description} }
    let(language) { nil }
    let(objects) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

    subject do
      begin
        XML.parse(described_class.generate_rss_feed(objects, feed_title, feed_url, description, language)).document
      rescue XML::Error
        XML.parse("<rss/>").document
      end
    end

    it "renders basic RSS structure" do
      expect(subject.xpath_nodes("/rss/@version").first.content).to eq(%{2.0})
      expect(subject.xpath_nodes("/rss/channel").size).to eq(1)
    end

    context "given HTML characters in feed title" do
      let(feed_title) { %{Test & "Quotes" <script>alert('xss')</script>} }

      it "escapes HTML characters" do
        expect(subject.xpath_nodes("/rss/channel/title/text()")).to contain_exactly(feed_title)
      end
    end

    context "given HTML characters in feed URL" do
      let(feed_url) { %{https://test.test?param="value"&other=1} }

      it "escapes HTML characters" do
        expect(subject.xpath_nodes("/rss/channel/link/text()")).to contain_exactly(feed_url)
      end
    end

    context "given HTML characters in description" do
      let(description) { %{Test & description with <em>emphasis</em> & "quotes"} }

      it "escapes HTML characters in description" do
        expect(subject.xpath_nodes("/rss/channel/description/text()")).to contain_exactly(%{Test & description with <em>emphasis</em> & "quotes"})
      end
    end

    it "includes other channel metadata" do
      expect(subject.xpath_nodes("/rss/channel/language")).to be_empty
      expect(subject.xpath_nodes("/rss/channel/generator/text()")).to contain_exactly(%{Ktistec})
      expect(subject.xpath_nodes("/rss/channel/atom:link/@href")).to contain_exactly(%{https://test.test/feed.rss})
      expect(subject.xpath_nodes("/rss/channel/atom:link/@rel")).to contain_exactly(%{self})
      expect(subject.xpath_nodes("/rss/channel/atom:link/@type")).to contain_exactly(%{application/rss+xml})
      expect(subject.xpath_nodes("/rss/channel/lastBuildDate/text()")).not_to be_nil
    end

    context "with language specified" do
      let(language) { %{en-US} }

      it "includes language in channel metadata" do
        expect(subject.xpath_nodes("/rss/channel/language/text()")).to contain_exactly(%{en-US})
      end
    end

    context "with an object" do
      let_build(:actor, name: %{Test Author}, username: %{testuser})
      let_build(:object, name: %{Test Post Title}, content: %{This is the content}, published: Time.utc(2023, 1, 15, 10, 30, 0), attributed_to: actor)

      before_each { objects << object }

      it "includes item" do
        expect(subject.xpath_nodes("/rss/channel/item").size).to eq(1)
        expect(subject.xpath_nodes("/rss/channel/item/title/text()")).to contain_exactly(%{Test Post Title})
        expect(subject.xpath_nodes("/rss/channel/item/link/text()")).to contain_exactly(object.iri)
        expect(subject.xpath_nodes("/rss/channel/item/description/text()")).to contain_exactly(%{This is the content})
        expect(subject.xpath_nodes("/rss/channel/item/pubDate/text()")).to contain_exactly(%{Sun, 15 Jan 2023 10:30:00 +0000})
        expect(subject.xpath_nodes("/rss/channel/item/guid/text()")).to contain_exactly(object.iri)
        expect(subject.xpath_nodes("/rss/channel/item/guid/@isPermaLink").first.content).to eq(%{true})
        expect(subject.xpath_nodes("/rss/channel/item/author/text()")).to contain_exactly(%{testuser@test.test})
      end

      context "with HTML in object title" do
        before_each { object.assign(name: %{<strong>This is a very long title with <em>HTML tags</em> that should be stripped and truncated</strong>}) }

        it "strips HTML from title and truncates" do
          expect(subject.xpath_nodes("/rss/channel/item/title/text()")).to contain_exactly(%{This is a very long title with HTML tags that shou…})
        end
      end

      context "with special characters in object title" do
        before_each { object.assign(name: %{Title with & ampersand "quotes" <tags>}) }

        it "handles title with special characters" do
          expect(subject.xpath_nodes("/rss/channel/item/title/text()")).to contain_exactly(%{Title with & ampersand "quotes" })
        end
      end

      context "when name is nil" do
        before_each { object.assign(name: nil, content: %{This content will become the title}) }

        it "uses content as title" do
          expect(subject.xpath_nodes("/rss/channel/item/title/text()")).to contain_exactly(%{This content will become the title})
        end
      end

      context "with ]]> in object name" do
        before_each do
          object.assign(name: %{Title]]><injected/><![CDATA[trailing})
        end

        it "produces well-formed XML" do
          expect(subject.xpath_nodes("/rss/channel/item").size).to eq(1)
        end

        it "does not allow XML injection" do
          expect(subject.xpath_nodes("//injected")).to be_empty
        end
      end

      context "with HTML in object content" do
        before_each { object.assign(content: %{<p>Content with <strong>HTML</strong> & "quotes" & ampersands</p>}) }

        it "handles content with HTML" do
          expect(subject.xpath_nodes("/rss/channel/item/description/text()")).to contain_exactly(%{<p>Content with <strong>HTML</strong> &amp; "quotes" &amp; ampersands</p>})
        end
      end

      context "with ]]> in object content" do
        before_each do
          object.assign(content: %{normal content]]><injected/><![CDATA[trailing})
        end

        it "produces well-formed XML" do
          expect(subject.xpath_nodes("/rss/channel/item").size).to eq(1)
        end

        it "does not allow XML injection" do
          expect(subject.xpath_nodes("//injected")).to be_empty
        end
      end

      context "with <script> in object content" do
        before_each do
          object.assign(content: %{<p>Real<script>alert(1)</script> content</p>})
        end

        it "sanitizes the script tag out of the description" do
          description = subject.xpath_nodes("/rss/channel/item/description/text()").join(&.content)
          expect(description).to match(/Real content/)
          expect(description).not_to match(/<script>/)
        end
      end

      context "with javascript: URL in object content" do
        before_each do
          object.assign(content: %{<a href="javascript:alert(1)">click</a>})
        end

        it "sanitizes the javascript: href out of the description" do
          description_text = subject.xpath_nodes("/rss/channel/item/description/text()").join(&.content)
          expect(description_text).not_to match(/javascript:/)
          expect(description_text).to match(/click/)
        end
      end

      context "with URLs in object" do
        before_each { object.assign(urls: [%{https://test.test/objects/123?param="value"&other=1}]) }

        it "escapes URL" do
          expect(subject.xpath_nodes("/rss/channel/item/link/text()")).to contain_exactly(%{https://test.test/objects/123?param="value"&other=1})
          expect(subject.xpath_nodes("/rss/channel/item/guid/text()")).to contain_exactly(%{https://test.test/objects/123?param="value"&other=1})
        end
      end

      context "with special characters in author username" do
        before_each { actor.assign(username: %{user&name}) }

        it "escapes author username" do
          expect(subject.xpath_nodes("/rss/channel/item/author/text()")).to contain_exactly(%{user&name@test.test})
        end
      end

      context "with HTML in author username" do
        before_each { actor.assign(username: %{<script>alert(1)</script>evil}) }

        it "strips HTML" do
          author_text = subject.xpath_nodes("/rss/channel/item/author/text()").join(&.content)
          expect(author_text).not_to match(/<script>/)
          expect(author_text).to eq("evil@test.test")
        end
      end

      context "with HTML in author name and no object name or content" do
        before_each do
          actor.assign(name: %{<script>alert(1)</script>Evil Actor})
          object.assign(name: nil, content: nil)
        end

        it "strips HTML from the title fallback" do
          title = subject.xpath_nodes("/rss/channel/item/title/text()").join(&.content)
          expect(title).not_to match(/<script>/)
          expect(title).to eq("Post by Evil Actor")
        end
      end
    end

    context "with two objects" do
      let_build(:object, named: :object1)
      let_build(:object, named: :object2)

      before_each do
        objects << object1
        objects << object2
      end

      it "includes two items" do
        expect(subject.xpath_nodes("/rss/channel/item").size).to eq(2)
      end
    end
  end
end
