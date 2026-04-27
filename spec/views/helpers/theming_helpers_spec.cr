require "../../../src/models/activity_pub/actor/person"
require "../../../src/models/activity_pub/object/note"

require "./support_spec"

Spectator.describe "helpers" do
  setup_spec

  include Ktistec::ViewHelper

  describe ".actor_states" do
    let_build(:actor, named: :author)
    let_build(:actor, named: :actor)
    let_build(:note, attributed_to: author)
    let(followed_actors) { nil }

    subject do
      self.class.actor_states(
        note, author, actor,
        followed_actors,
      )
    end

    it "returns empty array" do
      expect(subject).to be_empty
    end

    context "with followed author" do
      let(followed_actors) { Set{author.iri} }

      it "includes author-followed-by-me" do
        expect(subject).to contain("author-followed-by-me")
      end

      it "does not include actor-followed-by-me" do
        expect(subject).not_to contain("actor-followed-by-me")
      end

      context "and followed actor" do
        let(followed_actors) { Set{author.iri, actor.iri} }

        it "includes author-followed-by-me and actor-followed-by-me" do
          expect(subject).to contain("author-followed-by-me", "actor-followed-by-me")
        end

        context "unless actor is the author" do
          let(:actor) { author }

          it "does not include actor-followed-by-me" do
            expect(subject).not_to contain("actor-followed-by-me")
          end
        end
      end
    end
  end

  describe ".object_states" do
    let_build(:note)

    subject { self.class.object_states(note) }

    it "only includes visibility-public" do
      expect(subject).to contain_exactly("visibility-public")
    end

    context "when object is sensitive" do
      before_each { note.assign(sensitive: true) }

      it "includes is-sensitive" do
        expect(subject).to contain("is-sensitive")
      end
    end

    context "when object is local" do
      let_build(:note, local: true)

      it "includes is-draft" do
        expect(subject).to contain("is-draft")
      end

      context "and is published" do
        before_each { note.assign(published: Time.local) }

        it "does not include is-draft" do
          expect(subject).to_not contain("is-draft")
        end
      end
    end

    context "when object is deleted" do
      before_each { note.delete! }

      it "includes is-deleted" do
        expect(subject).to contain("is-deleted")
      end
    end

    context "when object is blocked" do
      before_each { note.block! }

      it "includes is-blocked" do
        expect(subject).to contain("is-blocked")
      end
    end

    context "when object has replies" do
      before_each { note.assign(replies_count: 5_i64) }

      it "includes has-replies" do
        expect(subject).to contain("has-replies")
      end
    end

    context "when object has a quote" do
      before_each { note.assign(quote_iri: "https://remote/quote") }

      it "includes has-quote" do
        expect(subject).to contain("has-quote")
      end
    end

    context "when object has media attachments" do
      let(attachment) do
        ActivityPub::Object::Attachment.new(
          url: "https://example.com/image.jpg",
          media_type: "image/jpeg",
        )
      end

      before_each do
        note.assign(attachments: [attachment])
      end

      it "includes has-media" do
        expect(subject).to contain("has-media")
      end
    end

    context "when object is addressed to followers only" do
      before_each do
        note.assign(to: [note.attributed_to.followers.not_nil!])
      end

      it "includes visibility-private" do
        expect(subject).to contain("visibility-private")
      end
    end

    context "when object is addressed to specific actors" do
      let_build(:actor)

      before_each do
        note.assign(to: [actor.iri])
      end

      it "includes visibility-direct" do
        expect(subject).to contain("visibility-direct")
      end
    end
  end

  describe ".mention_states" do
    let_build(:note)
    let_build(:actor)

    subject { self.class.mention_states(note, actor) }

    it "returns empty array" do
      expect(subject).to be_empty
    end

    context "when actor is mentioned" do
      let_build(:actor, named: other)

      let_create!(:mention, named: nil, href: actor.iri, name: "me", subject: note)
      let_create!(:mention, named: nil, href: other.iri, name: "other", subject: note)

      it "includes mentions-me" do
        expect(subject).to contain("mentions-me")
      end

      it "does not include mentions-only-me" do
        expect(subject).not_to contain("mentions-only-me")
      end
    end

    context "when actor is the only mention" do
      let_create!(:mention, named: nil, href: actor.iri, name: "me", subject: note)

      it "does not include mentions-me" do
        expect(subject).not_to contain("mentions-me")
      end

      it "includes mentions-only-me" do
        expect(subject).to contain("mentions-only-me")
      end
    end
  end

  describe ".quote_states" do
    let_build(:note)
    let_build(:actor)

    subject { self.class.quote_states(note, actor) }

    it "returns empty array" do
      expect(subject).to be_empty
    end

    context "when object quotes actor's post" do
      let_create(:note, named: :quote, attributed_to: actor)

      before_each { note.assign(quote: quote) }

      it "contains quotes-me" do
        expect(subject).to contain("quotes-me")
      end
    end

    context "when object quotes another actor's post" do
      let_create(:note, named: :quote)

      before_each { note.assign(quote: quote) }

      it "does not contain quotes-me" do
        expect(subject).not_to contain("quotes-me")
      end
    end
  end

  describe ".object_data_attributes" do
    let_create(:note)
    let_build(:actor, named: :author, username: "alice")
    let_build(:actor, named: :sharer, username: "bob")
    let_create!(:hashtag, named: nil, name: "ruby", subject: note)
    let_create!(:hashtag, named: nil, name: "crystal", subject: note)
    let_create!(:mention, named: nil, name: "alice", subject: note)
    let_create!(:mention, named: nil, name: "bob", subject: note)
    let(followed_hashtags) { nil }
    let(followed_mentions) { nil }

    subject do
      self.class.object_data_attributes(
        note, author, sharer,
        followed_hashtags,
        followed_mentions,
      )
    end

    it "includes object ID" do
      expect(subject["data-object-id"]).to eq(note.id.to_s)
    end

    it "includes author handle" do
      expect(subject["data-author-handle"]).to eq("alice@remote")
    end

    it "includes author IRI" do
      expect(subject["data-author-iri"]).to eq(author.iri)
    end

    it "includes actor handle" do
      expect(subject["data-actor-handle"]).to eq("bob@remote")
    end

    it "includes actor IRI" do
      expect(subject["data-actor-iri"]).to eq(sharer.iri)
    end

    it "does not include data-followed-hashtags" do
      expect(subject.has_key?("data-followed-hashtags")).to be_false
    end

    context "with followed hashtags" do
      let(followed_hashtags) { Set{"ruby", "golang"} }

      it "includes data-followed-hashtags" do
        expect(subject["data-followed-hashtags"]).to eq("ruby")
      end
    end

    it "does not include data-followed-mentions" do
      expect(subject.has_key?("data-followed-mentions")).to be_false
    end

    context "with followed mentions" do
      let(followed_mentions) { Set{"alice", "charlie"} }

      it "includes data-followed-mentions" do
        expect(subject["data-followed-mentions"]).to eq("alice")
      end
    end

    it "includes data-hashtags" do
      expect(subject["data-hashtags"]).to eq("ruby crystal")
    end

    it "includes data-mentions" do
      expect(subject["data-mentions"]).to eq("alice bob")
    end
  end

  PARSER_OPTIONS =
    XML::HTMLParserOptions::NOIMPLIED |
      XML::HTMLParserOptions::NODEFDTD

  describe ".actor_icon" do
    let_build(:actor)

    let(classes) { nil }
    subject { XML.parse_html(self.class.actor_icon(actor, classes), PARSER_OPTIONS) }

    context "given an icon" do
      before_each { actor.assign(icon: "https://example.com/icon.png", name: "Test Actor").save }

      it "renders an img tag with src attribute" do
        expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain_exactly("https://example.com/icon.png")
      end

      it "renders an img tag with alt attribute" do
        expect(subject.xpath_nodes("//img/@alt").map(&.text)).to contain_exactly("Test Actor")
      end

      it "renders an img tag with data-actor-id attribute" do
        expect(subject.xpath_nodes("//img/@data-actor-id").map(&.text)).to contain_exactly(actor.id.to_s)
      end

      it "renders an img tag with loading attribute" do
        expect(subject.xpath_nodes("//img/@loading").map(&.text)).to contain_exactly("lazy")
      end

      context "and classes" do
        let(classes) { "ui avatar image" }

        it "renders an img tag with the classes" do
          expect(subject.xpath_nodes("//img/@class").map(&.text)).to contain_exactly("ui avatar image")
        end
      end
    end

    context "given an icon that contains a double-quote" do
      before_each { actor.assign(icon: %(https://evil.example/x"onerror="alert(1)), name: "Test Actor").save }

      it "escapes the src attribute" do
        expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain_exactly(%(https://evil.example/x"onerror="alert(1)))
      end

      it "does not produce an onerror attribute" do
        expect(subject.xpath_nodes("//img/@onerror")).to be_empty
      end
    end

    context "given classes containing a double-quote" do
      let(classes) { %(ui" onclick="alert(1)) }

      before_each { actor.assign(icon: "https://example.com/icon.png", name: "Test Actor").save }

      it "escapes the class attribute value" do
        expect(subject.xpath_nodes("//img/@class").map(&.text)).to contain_exactly(%(ui" onclick="alert(1)))
      end

      it "does not produce an onclick attribute" do
        expect(subject.xpath_nodes("//img/@onclick")).to be_empty
      end
    end

    # Set icon after save so the model's `before_validate` property
    # scrub does not null it -- this exercises the helper's defense in
    # depth, in case the scrub is ever bypassed or broken.

    context "given an icon with a javascript scheme" do
      before_each { actor.assign(name: "Test Actor").save.assign(icon: "javascript:alert(1)") }

      it "falls back to the default avatar" do
        expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain_exactly("/images/avatars/fallback.png")
      end
    end

    context "given an icon with a control-character-obfuscated scheme" do
      before_each { actor.assign(name: "Test Actor").save.assign(icon: "java\u0000script:alert(1)") }

      it "falls back to the default avatar" do
        expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain_exactly("/images/avatars/fallback.png")
      end
    end
  end

  describe ".actor_background_style" do
    let_build(:actor)

    subject { self.class.actor_background_style(actor) }

    it "returns nil" do
      expect(subject).to be_nil
    end

    context "given an empty image" do
      before_each { actor.assign(image: "").save }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given an image" do
      before_each { actor.assign(image: "http://example.com/banner.png").save }

      it "wraps the URL" do
        expect(subject).to eq(%(background-image: url("http://example.com/banner.png");))
      end
    end

    context "given an image" do
      before_each { actor.assign(image: "https://example.com/banner.png").save }

      it "wraps the URL" do
        expect(subject).to eq(%(background-image: url("https://example.com/banner.png");))
      end
    end

    # the actor's `before_validate` drops unsafe schemes, so set
    # the image after save to exercise the helper's defense.

    context "given a javascript scheme" do
      before_each { actor.save.assign(image: "javascript:alert(1)") }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given a data scheme" do
      before_each { actor.save.assign(image: "data:image/png;base64,AAAA") }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given a non-navigational scheme" do
      before_each { actor.save.assign(image: "mailto:nobody@example.com") }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given an obfuscated scheme" do
      before_each { actor.save.assign(image: "java\u0000script:alert(1)") }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given a CSS-breakout payload" do
      before_each { actor.save.assign(image: %[http://x);position:fixed;top:0;background-image:url(http://attacker/x]) }

      it "percent-encodes the payload" do
        expect(subject).to eq(%[background-image: url("http://x%29;position:fixed;top:0;background-image:url%28http://attacker/x");])
      end
    end

    context "given a payload with a double quote" do
      before_each { actor.save.assign(image: %(http://x"onerror=alert(1))) }

      it "percent-encodes the double quote" do
        expect(subject).to eq(%(background-image: url("http://x%22onerror=alert%281%29");))
      end
    end

    context "given a payload with a backslash" do
      before_each { actor.save.assign(image: %(http://x\\foo)) }

      it "percent-encodes the backslash" do
        expect(subject).to eq(%(background-image: url("http://x%5Cfoo");))
      end
    end
  end

  describe ".actor_type_class" do
    let_build(:person)

    it "returns actor type class" do
      expect(self.class.actor_type_class(person)).to eq("actor-person")
    end

    context "given nil" do
      it "returns empty string" do
        expect(self.class.actor_type_class(nil)).to eq("")
      end
    end
  end

  describe ".object_type_class" do
    let_build(:note)

    it "returns object type class" do
      expect(self.class.object_type_class(note)).to eq("object-note")
    end

    context "given nil" do
      it "returns empty string" do
        expect(self.class.object_type_class(nil)).to eq("")
      end
    end
  end
end
