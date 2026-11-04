require "../../src/serializers/post"
require "../../src/models/tag/label"

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
      to: ["https://www.w3.org/ns/activitystreams#Public"],
      cc: ["https://remote/actors/alice/followers"],
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

    let_create(:actor, named: :owner)

    subject { described_class.from(object, owner.iri) }

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

    it "carries the post's to" do
      expect(subject.to).to eq(["https://www.w3.org/ns/activitystreams#Public"])
    end

    it "carries the post's cc" do
      expect(subject.cc).to eq(["https://remote/actors/alice/followers"])
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

    describe "#labels" do
      let_create!(:label, name: "cats", owner: owner, subject: object)

      it "carries the owner's labels" do
        expect(subject.labels).to eq(["cats"])
      end

      context "given another actor labeled the post" do
        let_create(:actor, named: :other)
        let_create!(:label, name: "cats", owner: other, subject: object)

        it "is empty" do
          expect(subject.labels).to be_empty
        end
      end
    end

    it "carries the post's author's IRI" do
      expect(subject.author).to eq(object.attributed_to_iri)
    end

    describe "#deleted" do
      it "is false for a post that has not been deleted" do
        expect(subject.deleted).to be_false
      end

      context "given the post is deleted" do
        before_each { object.delete! }

        it "is true" do
          expect(subject.deleted).to be_true
        end
      end
    end

    describe "#blocked" do
      it "is false for a post that has not been blocked" do
        expect(subject.blocked).to be_false
      end

      context "given the post is blocked" do
        before_each { object.block! }

        it "is true" do
          expect(subject.blocked).to be_true
        end
      end
    end

    describe "#timeline" do
      context "given the post arrived in the owner's timeline in a create" do
        before_each { put_in_timeline_create(owner, object.save) }

        it "is create" do
          expect(subject.timeline).to eq("create")
        end
      end

      context "given the post arrived in the owner's timeline in an announce" do
        before_each { put_in_timeline_announce(owner, object.save) }

        it "is announce" do
          expect(subject.timeline).to eq("announce")
        end
      end

      context "given the post arrived only in another actor's timeline" do
        let_create(:actor, named: :other)

        before_each { put_in_timeline_announce(other, object.save) }

        it "is nil" do
          expect(subject.timeline).to be_nil
        end
      end
    end

    describe "#poll" do
      context "given a poll" do
        let_create(:question)
        let_create!(
          :poll,
          question: question,
          options: [Poll::Option.new("yes"), Poll::Option.new("no")],
          multiple_choice: true,
          closed_at: Time.utc(2026, 11, 1),
        )

        subject { described_class.from(question, owner.iri) }

        it "carries its options" do
          expect(subject.poll.try(&.options)).to eq(["yes", "no"])
        end

        it "carries whether it is multiple choice" do
          expect(subject.poll.try(&.multiple_choice)).to be_true
        end

        it "carries when it closes" do
          expect(subject.poll.try(&.closed_at)).to eq(Time.utc(2026, 11, 1))
        end
      end
    end
  end

  describe Serializers::Post::Poll do
    it "writes a closing time in SQLite's format" do
      expect(described_class.new(["yes", "no"], false, Time.utc(2026, 11, 1)).to_json).to eq(%({"options":["yes","no"],"multiple_choice":false,"closed_at":"2026-11-01 00:00:00.000"}))
    end

    it "writes a missing closing time as null" do
      expect(described_class.new(["yes", "no"], false, nil).to_json).to eq(%({"options":["yes","no"],"multiple_choice":false,"closed_at":null}))
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
