require "../../src/serializers/post"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Serializers::Post do
  setup_spec

  describe ".from" do
    let(attachment) { ActivityPub::Object::Attachment.new("https://remote/cat.jpg", "image/jpeg", "A cat") }
    let_build(:hashtag, name: "cats", href: "https://remote/tags/cats")
    let_build(:mention, name: "alice@remote", href: "https://remote/actors/alice")
    let_build(
      :object,
      name: "Cats",
      summary: "<p>About a cat</p>",
      content: "<p>A cat</p>",
      audience: ["https://remote/c/cats"],
      attachments: [attachment],
      published: Time.utc(2026, 10, 22, 12, 0, 0),
      in_reply_to_iri: "https://remote/objects/parent",
      thread: "https://remote/objects/root",
      quote_iri: "https://remote/objects/quoted",
      language: "en",
      sensitive: true,
      hashtags: [hashtag],
      mentions: [mention],
    )

    subject { described_class.from(object) }

    it "carries the post's IRI" do
      expect(subject.iri).to eq(object.iri)
    end

    it "carries the post's type" do
      expect(subject.type).to eq("Object")
    end

    it "carries the post's name" do
      expect(subject.name).to eq("Cats")
    end

    it "carries the post's summary" do
      expect(subject.summary).to eq("<p>About a cat</p>")
    end

    it "carries the post's content" do
      expect(subject.content).to eq("<p>A cat</p>")
    end

    context "given Markdown content" do
      before_each { object.assign(media_type: "text/markdown", content: "*A cat*") }

      it "converts the Markdown content to HTML" do
        expect(subject.content).to eq("<p><em>A cat</em></p>\n")
      end
    end

    it "carries the post's audience" do
      expect(subject.audience).to eq(["https://remote/c/cats"])
    end

    it "carries the post's attachments" do
      expect(subject.attachments).to eq([Serializers::Post::Attachment.new("https://remote/cat.jpg", "image/jpeg", "A cat")])
    end

    it "carries the post's published time" do
      expect(subject.published).to eq(Time.utc(2026, 10, 22, 12, 0, 0))
    end

    it "carries the post's in-reply-to IRI" do
      expect(subject.in_reply_to).to eq("https://remote/objects/parent")
    end

    it "carries the post's thread" do
      expect(subject.thread).to eq("https://remote/objects/root")
    end

    it "carries the post's quote IRI" do
      expect(subject.quote).to eq("https://remote/objects/quoted")
    end

    it "carries the post's language" do
      expect(subject.language).to eq("en")
    end

    it "carries the post's sensitivity" do
      expect(subject.sensitive).to be_true
    end

    it "carries the post's hashtags" do
      expect(subject.hashtags).to eq([Serializers::Post::Tag.new("cats", "https://remote/tags/cats")])
    end

    it "carries the post's mentions" do
      expect(subject.mentions).to eq([Serializers::Post::Tag.new("alice@remote", "https://remote/actors/alice")])
    end

    it "carries the post's author's IRI" do
      expect(subject.author).to eq(object.attributed_to_iri)
    end
  end

  describe Serializers::Post::Attachment do
    it "writes a missing caption as null" do
      expect(described_class.new("https://remote/cat.jpg", "image/jpeg", nil).to_json).to eq(%({"url":"https://remote/cat.jpg","media_type":"image/jpeg","caption":null}))
    end
  end

  describe Serializers::Post::Tag do
    it "writes a missing href as null" do
      expect(described_class.new("cats", nil).to_json).to eq(%({"name":"cats","href":null}))
    end
  end
end
