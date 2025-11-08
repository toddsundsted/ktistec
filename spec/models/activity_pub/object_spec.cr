require "../../../src/models/activity_pub/object"
require "../../../src/models/activity_pub/activity/announce"
require "../../../src/models/activity_pub/activity/like"
require "../../../src/services/thread_analysis_service"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class FooBarObject < ActivityPub::Object
end

Spectator.describe ActivityPub::Object do
  setup_spec

  describe "#source=" do
    subject { Factory.build(:object, local: true) }
    let_create!(:actor, named: :foo, iri: "https://bar.com/foo", urls: ["https://bar.com/@foo"], username: "foo")
    let_create!(:actor, named: :bar, iri: "https://foo.com/bar", urls: ["https://foo.com/@bar"], username: "bar")
    let(source) { ActivityPub::Object::Source.new("foobar #foobar @foo@bar.com", "text/html") }

    it "assigns content" do
      expect{subject.assign(source: source).save}.to change{subject.content}
    end

    it "assigns media type" do
      expect{subject.assign(source: source).save}.to change{subject.media_type}
    end

    it "assigns attachments" do
      expect{subject.assign(source: source).save}.to change{subject.attachments}
    end

    it "assigns hashtags" do
      expect{subject.assign(source: source).save}.to change{subject.hashtags}
    end

    it "creates hashtags" do
      expect{subject.assign(source: source).save}.to change{Tag::Hashtag.count(subject_iri: subject.iri)}.by(1)
    end

    it "assigns mentions" do
      expect{subject.assign(source: source).save}.to change{subject.mentions}
    end

    it "creates mentions" do
      expect{subject.assign(source: source).save}.to change{Tag::Mention.count(subject_iri: subject.iri)}.by(1)
    end

    it "doesn't assign if the object isn't local" do
      expect{subject.assign(iri: "https://remote/object", source: source).save}.not_to change{subject.content}
    end

    context "addressing" do
      let_create!(:mention, subject: subject, href: bar.iri, name: bar.username)

      it "replaces mentions" do
        subject.assign(to: ["https://test.test/actor", "https://foo.com/bar"], source: source).save
        expect(subject.to).to eq(["https://test.test/actor", "https://bar.com/foo"])
      end

      let(followers) { subject.attributed_to.followers.not_nil! }

      context "when object is public" do
        before_each do
          subject.assign(
            to: ["https://www.w3.org/ns/activitystreams#Public"],
            cc: [followers],
            source: source
          ).save
        end

        it "sets the to field" do
          expect(subject.to).to contain_exactly("https://www.w3.org/ns/activitystreams#Public")
        end

        it "sets the cc field" do
          expect(subject.cc).to contain_exactly(followers, "https://bar.com/foo")
        end
      end

      context "when object is private" do
        before_each do
          subject.assign(
            to: [followers],
            cc: [] of String,
            source: source
          ).save
        end

        it "sets the to field" do
          expect(subject.to).to contain_exactly(followers)
        end

        it "sets the cc field" do
          expect(subject.cc).to contain_exactly("https://bar.com/foo")
        end
      end

      context "when object is direct" do
        before_each do
          subject.assign(
            to: [] of String,
            cc: [] of String,
            source: source
          ).save
        end

        it "sets the to field" do
          expect(subject.to).to contain_exactly("https://bar.com/foo")
        end

        it "sets the cc field" do
          expect(subject.cc).to be_empty
        end
      end
    end
  end

  context "when validating" do
    subject { described_class.new(iri: "https://test.test/#{random_string}") }

    it "returns false if the canonical path is not valid" do
      expect(subject.assign(canonical_path: "foobar").valid?).to be_false
    end

    it "returns false if the language is not supported" do
      expect(subject.assign(language: "123").valid?).to be_false
    end

    it "is valid" do
      expect(subject.valid?).to be_true
    end
  end

  context "given embedded objects" do
    let(json) do
      <<-JSON
        {
          "@context":[
            "https://www.w3.org/ns/activitystreams",
            {"Hashtag":"as:Hashtag"}
          ],
          "@id":"https://remote/foo_bar",
          "@type":"FooBarObject",
          "attributedTo":{
            "id":"attributed to link"
          },
          "inReplyTo":{
            "id":"in reply to link"
          },
          "replies":{
            "id":"replies link",
            "type":"Collection"
          }
        }
      JSON
    end

    it "gets the ids" do
      object = described_class.from_json_ld(json)
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
    end
  end

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams",
          {"Hashtag":"as:Hashtag","sensitive":"as:sensitive"},
          {"toot":"http://joinmastodon.org/ns#"}
        ],
        "@id":"https://remote/foo_bar",
        "@type":"FooBarObject",
        "published":"2016-02-15T10:20:30Z",
        "updated":"2016-02-15T11:30:45Z",
        "attributedTo":"attributed to link",
        "inReplyTo":"in reply to link",
        "replies":"replies link",
        "to":"to link",
        "cc":["cc link"],
        "audience":["audience link"],
        "name":"123",
        "summary":"abc",
        "sensitive":true,
        "content":"abc",
        "contentMap":{
          "en":"abc"
        },
        "mediaType":"xyz",
        "tag":[
          {"type":"Hashtag","href":"hashtag href","name":"#hashtag"},
          {"type":"Mention","href":"mention href","name":"@mention"}
        ],
        "attachment":[
          {
            "url":"attachment link",
            "mediaType":"type",
            "name":"caption"
          }
        ],
        "url":"url link"
      }
    JSON
  end

  # matcher
  class ::Tag
    def ===(other : Tag)
      self.type == other.type &&
        self.name == other.name &&
        self.href == other.href
    end
  end

  describe ".from_json_ld" do
    it "instantiates the subclass" do
      object = described_class.from_json_ld(json)
      expect(object.class).to eq(FooBarObject)
    end

    it "creates a new instance" do
      object = described_class.from_json_ld(json).save
      expect(object.iri).to eq("https://remote/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.updated).to eq(Time.utc(2016, 2, 15, 11, 30, 45))
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies_iri).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.audience).to eq(["audience link"])
      expect(object.language).to eq("en")
      expect(object.name).to eq("123")
      expect(object.summary).to eq("abc")
      expect(object.sensitive).to be_true
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.hashtags.first).to match(Tag::Hashtag.new(name: "hashtag", href: "hashtag href"))
      expect(object.mentions.first).to match(Tag::Mention.new(name: "mention", href: "mention href"))
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption")])
      expect(object.urls).to eq(["url link"])
    end

    context "when addressed to the public collection" do
      let(json) { super.gsub("to link", "https://www.w3.org/ns/activitystreams#Public") }

      it "is visible" do
        object = described_class.from_json_ld(json).save
        expect(object.visible).to be_true
      end
    end

    context "when hashtag name is null" do
      let(json) { super.gsub(%q|"name":"#hashtag"|, %q|"name":null|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.hashtags).to be_empty
      end
    end

    context "when hashtag name is blank" do
      let(json) { super.gsub(%q|"name":"#hashtag"|, %q|"name":""|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.hashtags).to be_empty
      end
    end

    context "when mention name is null" do
      let(json) { super.gsub(%q|"name":"@mention"|, %q|"name":null|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.mentions).to be_empty
      end
    end

    context "when mention name is blank" do
      let(json) { super.gsub(%q|"name":"@mention"|, %q|"name":""|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.mentions).to be_empty
      end
    end

    context "when attachment url is null" do
      let(json) { super.gsub(%q|"url":"attachment link"|, %q|"url":null|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "when attachment url is blank" do
      let(json) { super.gsub(%q|"url":"attachment link"|, %q|"url":""|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "when attachment media type is null" do
      let(json) { super.gsub(%q|"mediaType":"type"|, %q|"mediaType":null|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "when attachment media type is blank" do
      let(json) { super.gsub(%q|"mediaType":"type"|, %q|"mediaType":""|) }

      it "is ignored" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "with focalPoint field" do
      let(json) { super.gsub(%q|"name":"caption"|, %q|"name":"caption","toot:focalPoint":[0.2,-0.4]|) }

      it "deserializes focal point" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption", {0.2, -0.4})])
      end
    end

    context "with focalPoint at center" do
      let(json) { super.gsub(%q|"name":"caption"|, %q|"name":"caption","toot:focalPoint":[0.0,0.0]|) }

      it "deserializes center focal point" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption", {0.0, 0.0})])
      end
    end

    context "with malformed focalPoint" do
      let(json) { super.gsub(%q|"name":"caption"|, %q|"name":"caption","toot:focalPoint":[0.0,null]|) }

      it "handles malformed focal point gracefully" do
        object = described_class.from_json_ld(json).save
        expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption")])
      end
    end

    # support Lemmy-style language property
    context "when language is present" do
      let(json) do
        <<-JSON
          {
            "@context": [
              "https://join-lemmy.org/context.json",
              "https://www.w3.org/ns/activitystreams"
            ],
            "@id":"https://remote/foo_bar",
            "@type":"FooBarObject",
            "language": {
              "identifier": "en",
              "name": "English"
            }
          }
        JSON
      end

      it "sets the language" do
        object = described_class.from_json_ld(json).save
        expect(object.language).to eq("en")
      end
    end

    context "when sensitive property is missing" do
      let(json) do
        <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "@id":"https://remote/foo_bar",
            "@type":"FooBarObject"
          }
        JSON
      end

      it "defaults sensitive to false" do
        object = described_class.from_json_ld(json).save
        expect(object.sensitive).to be_false
      end
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      object = described_class.new.from_json_ld(json).save
      expect(object.iri).to eq("https://remote/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.updated).to eq(Time.utc(2016, 2, 15, 11, 30, 45))
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies_iri).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.audience).to eq(["audience link"])
      expect(object.language).to eq("en")
      expect(object.name).to eq("123")
      expect(object.summary).to eq("abc")
      expect(object.sensitive).to be_true
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.hashtags.first).to match(Tag::Hashtag.new(name: "hashtag", href: "hashtag href"))
      expect(object.mentions.first).to match(Tag::Mention.new(name: "mention", href: "mention href"))
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption")])
      expect(object.urls).to eq(["url link"])
    end

    context "when addressed to the public collection" do
      let(json) { super.gsub("cc link", "https://www.w3.org/ns/activitystreams#Public") }

      it "is visible" do
        object = described_class.new.from_json_ld(json).save
        expect(object.visible).to be_true
      end
    end

    context "when hashtag name is null" do
      let(json) { super.gsub(%q|"name":"#hashtag"|, %q|"name":null|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.hashtags).to be_empty
      end
    end

    context "when hashtag name is blank" do
      let(json) { super.gsub(%q|"name":"#hashtag"|, %q|"name":""|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.hashtags).to be_empty
      end
    end

    context "when mention name is null" do
      let(json) { super.gsub(%q|"name":"@mention"|, %q|"name":null|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.mentions).to be_empty
      end
    end

    context "when mention name is blank" do
      let(json) { super.gsub(%q|"name":"@mention"|, %q|"name":""|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.mentions).to be_empty
      end
    end

    context "when attachment url is null" do
      let(json) { super.gsub(%q|"url":"attachment link"|, %q|"url":null|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "when attachment url is blank" do
      let(json) { super.gsub(%q|"url":"attachment link"|, %q|"url":""|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "when attachment media type is null" do
      let(json) { super.gsub(%q|"mediaType":"type"|, %q|"mediaType":null|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "when attachment media type is blank" do
      let(json) { super.gsub(%q|"mediaType":"type"|, %q|"mediaType":""|) }

      it "is ignored" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to be_empty
      end
    end

    context "with focalPoint field" do
      let(json) { super.gsub(%q|"name":"caption"|, %q|"name":"caption","toot:focalPoint":[0.2,-0.4]|) }

      it "deserializes focal point" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption", {0.2, -0.4})])
      end
    end

    context "with focalPoint at center" do
      let(json) { super.gsub(%q|"name":"caption"|, %q|"name":"caption","toot:focalPoint":[0.0,0.0]|) }

      it "deserializes center focal point" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption", {0.0, 0.0})])
      end
    end

    context "with malformed focalPoint" do
      let(json) { super.gsub(%q|"name":"caption"|, %q|"name":"caption","toot:focalPoint":[0.0,null]|) }

      it "handles malformed focal point gracefully" do
        object = described_class.new.from_json_ld(json).save
        expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type", "caption")])
      end
    end

    # support Lemmy-style language property
    context "when language is present" do
      let(json) do
        <<-JSON
          {
            "@context": [
              "https://join-lemmy.org/context.json",
              "https://www.w3.org/ns/activitystreams"
            ],
            "@id":"https://remote/foo_bar",
            "@type":"FooBarObject",
            "language": {
              "identifier": "en",
              "name": "English"
            }
          }
        JSON
      end

      it "sets the language" do
        object = described_class.from_json_ld(json).save
        expect(object.language).to eq("en")
      end
    end

    context "when sensitive property is missing" do
      let(json) do
        <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "@id":"https://remote/foo_bar",
            "@type":"FooBarObject"
          }
        JSON
      end

      it "defaults sensitive to false" do
        object = described_class.from_json_ld(json).save
        expect(object.sensitive).to be_false
      end
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      object = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(object.to_json_ld)).to eq(object)
    end

    context "with focal point" do
      let(:object) do
        described_class.new(
          iri: "https://test.test/objects/#{random_string}",
          attachments: [ActivityPub::Object::Attachment.new("https://example.com/image.jpg", "image/jpeg", "Test image", {0.5, -0.25})]
        ).save
      end

      let(json_ld) { JSON.parse(object.to_json_ld) }

      it "includes toot context in output" do
        context = json_ld["@context"].as_a
        toot_context = context.find! { |c| c.as_h? && c.as_h.has_key?("toot") }
        expect(toot_context.as_h["toot"]).to eq("http://joinmastodon.org/ns#")
      end

      it "serializes focal point in attachment" do
        attachments = json_ld["attachment"].as_a
        expect(attachments.first["focalPoint"]).to eq([0.5, -0.25])
      end

      it "round-trips focal point correctly" do
        restored = described_class.from_json_ld(object.to_json_ld)
        expect(restored.attachments).to eq(object.attachments)
      end
    end

    it "does not render a content map" do
      object = described_class.new(
        iri: "https://test.test/object",
        content: "abc"
      ).save
      expect(JSON.parse(object.to_json_ld).as_h).not_to have_key("contentMap")
    end

    it "renders hashtags" do
      object = described_class.new(
        iri: "https://test.test/object",
        hashtags: [Factory.build(:hashtag, name: "foo", href: "https://test.test/tags/foo")]
      ).save
      expect(JSON.parse(object.to_json_ld).dig("tag").as_a).to contain_exactly({"type" => "Hashtag", "name" => "#foo", "href" => "https://test.test/tags/foo"})
    end

    it "renders mentions" do
      object = described_class.new(
        iri: "https://test.test/object",
        mentions: [Factory.build(:mention, name: "foo@test.test", href: "https://test.test/actors/foo")]
      ).save
      expect(JSON.parse(object.to_json_ld).dig("tag").as_a).to contain_exactly({"type" => "Mention", "name" => "@foo@test.test", "href" => "https://test.test/actors/foo"})
    end

    it "renders sensitive property when true" do
      object = described_class.new(
        iri: "https://test.test/object",
        sensitive: true
      ).save
      expect(JSON.parse(object.to_json_ld).as_h["sensitive"]).to eq(true)
    end

    it "does not render sensitive property when false" do
      object = described_class.new(
        iri: "https://test.test/object",
        sensitive: false
      ).save
      expect(JSON.parse(object.to_json_ld).as_h.has_key?("sensitive")).to be_false
    end
  end

  describe "#make_delete_activity" do
    let_build(:actor, named: :attributed_to)

    subject do
      described_class.new(
        iri: "https://test.test/objects/object",
        attributed_to: attributed_to,
        to: ["to_iri"],
        cc: ["cc_iri"]
      )
    end

    it "instantiates a delete activity for the subject" do
      expect(subject.make_delete_activity).to be_a(ActivityPub::Activity::Delete)
    end

    it "assigns the subject's attributed_to as the actor" do
      expect(subject.make_delete_activity.actor).to eq(attributed_to)
    end

    it "assigns the subject as the object" do
      expect(subject.make_delete_activity.object).to eq(subject)
    end

    it "copies the subject's to" do
      expect(subject.make_delete_activity.to).to eq(["to_iri"])
    end

    it "copies the subject's cc" do
      expect(subject.make_delete_activity.cc).to eq(["cc_iri"])
    end
  end

  describe ".federated_posts" do
    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_create!(
        :object, named: post{{index}},
        attributed_to: actor{{index}},
        published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
        visible: {{index}}.odd?
      )
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

    it "instantiates the correct subclass" do
      expect(described_class.federated_posts(1, 2).first).to be_a(ActivityPub::Object)
    end

    it "filters out deleted posts" do
      post5.delete!
      expect(described_class.federated_posts(1, 2)).to eq([post3, post1])
    end

    it "filters out blocked posts" do
      post5.block!
      expect(described_class.federated_posts(1, 2)).to eq([post3, post1])
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(described_class.federated_posts(1, 2)).to eq([post3, post1])
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(described_class.federated_posts(1, 2)).to eq([post3, post1])
    end

    it "filters out non-public posts" do
      expect(described_class.federated_posts(1, 2)).to eq([post5, post3])
    end

    it "paginates the results" do
      expect(described_class.federated_posts(1, 2)).to eq([post5, post3])
      expect(described_class.federated_posts(2, 2)).to eq([post1])
      expect(described_class.federated_posts(2, 2).more?).not_to be_true
    end

    context "with a draft post" do
      let_create!(
        :object, named: :draft_post,
        published: nil,
        visible: true,
        local: true,
      )

      it "filters out draft posts" do
        expect(described_class.federated_posts(1, 10)).not_to contain(draft_post)
      end
    end
  end

  describe ".federated_posts_count" do
    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_create!(
        :object, named: post{{index}},
        attributed_to: actor{{index}},
        published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
        visible: {{index}}.odd?
      )
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

    it "instantiates the correct subclass" do
      expect(described_class.federated_posts_count).to be_a(Int64)
    end

    it "filters out deleted posts" do
      post5.delete!
      expect(described_class.federated_posts_count).to eq(2)
    end

    it "filters out blocked posts" do
      post5.block!
      expect(described_class.federated_posts_count).to eq(2)
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(described_class.federated_posts_count).to eq(2)
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(described_class.federated_posts_count).to eq(2)
    end

    it "filters out non-public posts" do
      expect(described_class.federated_posts_count).to eq(3)
    end

    context "with a draft post" do
      let_create!(
        :object, named: :draft_post,
        published: nil,
        visible: true,
        local: true
      )

      it "filters out draft posts" do
        expect(described_class.federated_posts_count).to eq(3)
      end
    end
  end

  macro public_post(index, factory)
    {% if factory == :create %}
      let_build(:object, named: post{{index}}, attributed_to: actor)
      let_build(:create, named: activity{{index}}, actor: actor, object: post{{index}})
    {% elsif factory == :announce %}
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: post{{index}}, attributed_to: actor{{index}})
      let_build(:announce, named: activity{{index}}, actor: actor, object: post{{index}})
    {% elsif factory == :like %}
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: post{{index}}, attributed_to: actor{{index}})
      let_build(:like, named: activity{{index}}, actor: actor, object: post{{index}})
    {% end %}
    before_each { put_in_outbox(actor, activity{{index}}) }
  end

  describe ".public_posts" do
    let(actor) { register.actor }

    public_post(1, :announce)
    public_post(2, :create)
    public_post(3, :announce)
    public_post(4, :create)
    public_post(5, :announce)

    it "instantiates the correct subclass" do
      expect(described_class.public_posts(1, 2).first).to be_a(ActivityPub::Object)
    end

    it "filters out deleted posts" do
      post5.delete!
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    it "filters out blocked posts" do
      post5.block!
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    it "filters out non-public posts" do
      post5.assign(visible: false).save
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    it "filters out replies" do
      post5.assign(in_reply_to: post3).save
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    it "filters out objects belonging to undone activities" do
      activity5.undo!
      expect(described_class.public_posts(1, 2)).to eq([post4, post3])
    end

    let_build(:create, actor: actor, object: post5)
    let_build(:outbox_relationship, named: :outbox, owner: actor, activity: create)

    it "paginates the results" do
      expect(described_class.public_posts(1, 2)).to eq([post5, post4])
      expect(described_class.public_posts(3, 2)).to eq([post1])
      expect(described_class.public_posts(3, 2).more?).not_to be_true
    end
  end

  describe ".public_posts_count" do
    let(actor) { register.actor }

    public_post(1, :announce)
    public_post(2, :create)
    public_post(3, :announce)
    public_post(4, :create)
    public_post(5, :announce)

    it "instantiates the correct subclass" do
      expect(described_class.public_posts_count).to be_a(Int64)
    end

    it "filters out deleted posts" do
      post5.delete!
      expect(described_class.public_posts_count).to eq(4)
    end

    it "filters out blocked posts" do
      post5.block!
      expect(described_class.public_posts_count).to eq(4)
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(described_class.public_posts_count).to eq(4)
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(described_class.public_posts_count).to eq(4)
    end

    it "filters out non-public posts" do
      post5.assign(visible: false).save
      expect(described_class.public_posts_count).to eq(4)
    end

    it "filters out replies" do
      post5.assign(in_reply_to: post3).save
      expect(described_class.public_posts_count).to eq(4)
    end

    it "filters out objects belonging to undone activities" do
      activity5.undo!
      expect(described_class.public_posts_count).to eq(4)
    end

    let_build(:create, actor: actor, object: post5)
    let_build(:outbox_relationship, named: :outbox, owner: actor, activity: create)

    it "returns the count" do
      expect(described_class.public_posts_count).to eq(5)
    end
  end

  describe ".latest_public_post" do
    let(actor) { register.actor }

    it "returns -1 if there are no posts" do
      expect(described_class.latest_public_post).to eq(-1)
    end

    context "given posts" do
      public_post(1, :announce)
      public_post(2, :create)
      public_post(3, :announce)

      # the type of the returned identifier is unspecified, but we
      # know it's the id of the activity associated with the latest
      # post, so test for that.

      it "returns the id" do
        expect(described_class.latest_public_post).to eq(activity3.id)
      end

      it "ignores activities from remote actors" do
        activity3.assign(actor: post3.attributed_to).save
        expect(described_class.latest_public_post).to eq(activity2.id)
      end

      it "ignores activities that are undone" do
        activity3.undo!
        expect(described_class.latest_public_post).to eq(activity2.id)
      end

      public_post(4, :like)

      it "ignores activities that are not create or announce" do
        expect(described_class.latest_public_post).to eq(activity3.id)
      end
    end
  end

  describe "#with_statistics!" do
    let(object) do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      )
    end

    let_build(:announce, object: object)
    let_build(:like, object: object)
    let_build(:dislike, object: object)

    it "updates announces count" do
      announce.save
      expect(object.with_statistics!.announces_count).to eq(1)
      expect(object.with_statistics!.likes_count).to eq(0)
      expect(object.with_statistics!.dislikes_count).to eq(0)
    end

    it "updates likes count" do
      like.save
      expect(object.with_statistics!.announces_count).to eq(0)
      expect(object.with_statistics!.likes_count).to eq(1)
      expect(object.with_statistics!.dislikes_count).to eq(0)
    end

    it "updates dislikes count" do
      dislike.save
      expect(object.with_statistics!.announces_count).to eq(0)
      expect(object.with_statistics!.likes_count).to eq(0)
      expect(object.with_statistics!.dislikes_count).to eq(1)
    end

    it "doesn't fail when the object hasn't been saved" do
      expect(object.with_statistics!.announces_count).to eq(0)
      expect(object.with_statistics!.likes_count).to eq(0)
      expect(object.with_statistics!.dislikes_count).to eq(0)
    end

    it "filters out undone announces" do
      announce.save.undo!
      expect(object.with_statistics!.announces_count).to eq(0)
    end

    it "filters out undone likes" do
      like.save.undo!
      expect(object.with_statistics!.likes_count).to eq(0)
    end

    it "filters out undone dislikes" do
      dislike.save.undo!
      expect(object.with_statistics!.dislikes_count).to eq(0)
    end
  end

  describe "#thread" do
    let_build(:object)

    it "sets thread to its iri" do
      expect{object.save}.to change{object.thread}.to(object.iri)
    end

    context "given a reply" do
      before_each { object.save.assign(thread: nil) }

      let_build(:object, named: reply, in_reply_to: object)

      context "and a thread on object" do
        before_each { object.assign(thread: "https://somewhere") }

        it "sets thread to object's thread" do
          expect{reply.save}.to change{reply.thread}.to("https://somewhere")
        end
      end

      context "and an in_reply_to_iri on object" do
        before_each { object.assign(in_reply_to_iri: "https://elsewhere") }

        it "sets thread to object's in_reply_to_iri" do
          expect{reply.save}.to change{reply.thread}.to("https://elsewhere")
        end
      end

      context "and an in_reply_to_iri on reply" do
        before_each { reply.assign(in_reply_to_iri: "https://nowhere") }

        it "sets thread to its in_reply_to_iri" do
          expect{reply.save}.to change{reply.thread}.to("https://nowhere")
        end
      end

      it "sets thread to object's iri" do
        expect{reply.save}.to change{reply.thread}.to(object.iri)
      end

      context "when saving the root in a thread" do
        before_each { reply.save }

        before_each { object.assign(in_reply_to_iri: "https://anywhere", thread: "https://anywhere") }

        it "sets reply's thread to object's thread" do
          expect{object.save}.to change{reply.reload!.thread}.to("https://anywhere")
        end
      end
    end
  end

  describe "#thread!" do
    let_build(:object)

    it "updates the thread" do
      expect{object.thread!}.to change{object.thread}.from(nil).to(object.iri)
    end

    it "saves the updated object" do
      expect{object.thread!}.to change{ActivityPub::Object.find?(object.iri)}.from(nil).to(object)
    end

    it "returns the thread" do
      expect(object.thread!).to eq(object.iri)
    end
  end

  context "when threaded" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}",
        attributed_to: Factory.build(:actor),
        visible: true,
      ).save
    end

    macro reply_to!(object, reply)
      {% actor = reply.name.gsub(/object/, "actor") %}
      let_create(:actor, named: {{actor}})
      let!({{reply}}) do
        described_class.new(
          iri: "https://test.test/objects/#{random_string}",
          attributed_to: {{actor}},
          in_reply_to: {{object}},
          visible: true,
        ).save
      end
    end

    # Nesting:
    # S           id=1
    #   1         id=2
    #     2       id=4
    #       3     id=5
    #   4         id=3
    #     5       id=6

    reply_to!(subject, object1)
    reply_to!(subject, object4)
    reply_to!(object1, object2)
    reply_to!(object2, object3)
    reply_to!(object4, object5)

    describe "#with_replies_count!" do
      it "returns the count of replies" do
        expect(subject.with_replies_count!.replies_count).to eq(5)
        expect(object5.with_replies_count!.replies_count).to eq(0)
      end

      it "omits deleted replies and their children" do
        object4.delete!
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits blocked replies and their children" do
        object4.block!
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits replies with deleted attributed to actors" do
        actor4.delete!
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits replies with blocked attributed to actors" do
        actor4.block!
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      context "given an actor" do
        let_build(:actor)

        it "doesn't count any replies" do
          expect(subject.with_replies_count!(actor).replies_count).to eq(0)
        end

        context "and an approved object" do
          let_create!(:approved_relationship, named: :approved, actor: actor, object: object5)

          it "omits unapproved replies but includes their approved children" do
            expect(subject.with_replies_count!(actor).replies_count).to eq(1)
          end

          it "doesn't include the actor's unapproved replies" do
            object4.assign(attributed_to: actor).save
            expect(subject.with_replies_count!(actor).replies_count).to eq(1)
          end
        end
      end
    end

    describe "#replies" do
      let_build(:actor)

      it "returns replies" do
        expect(subject.replies(for_actor: actor)).to eq([object1, object4])
        expect(object1.replies(for_actor: actor)).to eq([object2])
        expect(object5.replies(for_actor: actor)).to be_empty
      end

      it "omits deleted replies" do
        object4.delete!
        expect(subject.replies(for_actor: actor)).to eq([object1])
      end

      it "omits blocked replies" do
        object4.block!
        expect(subject.replies(for_actor: actor)).to eq([object1])
      end

      it "omits destroyed replies" do
        object4.destroy
        expect(subject.replies(for_actor: actor)).to eq([object1])
      end

      it "omits replies with deleted attributed to actors" do
        actor4.delete!
        expect(subject.replies(for_actor: actor)).to eq([object1])
      end

      it "omits replies with blocked attributed to actors" do
        actor4.block!
        expect(subject.replies(for_actor: actor)).to eq([object1])
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        expect(subject.replies(for_actor: actor)).to eq([object1])
      end

      it "omits unapproved replies" do
        expect(subject.replies(approved_by: actor)).to be_empty
      end

      context "and an approved object" do
        let_create!(:approved_relationship, named: :approved, actor: actor, object: object4)

        it "returns approved replies" do
          expect(subject.replies(approved_by: actor)).to eq([object4])
        end

        it "omits deleted replies" do
          object4.delete!
          expect(subject.replies(approved_by: actor)).to be_empty
        end

        it "omits blocked replies" do
          object4.block!
          expect(subject.replies(approved_by: actor)).to be_empty
        end

        it "omits destroyed replies" do
          object4.destroy
          expect(subject.replies(approved_by: actor)).to be_empty
        end

        it "omits replies with deleted attributed to actors" do
          actor4.delete!
          expect(subject.replies(approved_by: actor)).to be_empty
        end

        it "omits replies with blocked attributed to actors" do
          actor4.block!
          expect(subject.replies(approved_by: actor)).to be_empty
        end

        it "omits replies with destroyed attributed to actors" do
          actor4.destroy
          expect(subject.replies(approved_by: actor)).to be_empty
        end

        it "omits non-visible replies even when approved" do
          object4.assign(visible: false).save
          expect(subject.replies(approved_by: actor)).not_to contain(object4)
        end
      end
    end

    describe "#thread" do
      let_build(:actor)

      it "returns all replies properly nested" do
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5])
        expect(object1.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5])
        expect(object5.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5])
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "returns the depths" do
        expect(object5.thread(for_actor: actor).map(&.depth)).to eq([0, 1, 2, 3, 1, 2])
      end

      context "when the root is missing" do
        before_each { subject.assign(in_reply_to_iri: "https://no.where/object").save }

        it "returns the thread" do
          # the operation above changes all of the `thread` properties in the thread, so reload
          expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5].map(&.reload!))
        end
      end

      context "given a reply by the original poster" do
        before_each { object4.assign(attributed_to: subject.attributed_to).save }

        it "prioritizes the reply" do
          expect(subject.thread(for_actor: actor)).to eq([subject, object4, object5, object1, object2, object3])
        end
      end

      context "given an approval" do
        it "only includes the subject" do
          expect(subject.thread(approved_by: actor)).to eq([subject])
        end

        context "and an approved object" do
          let_create!(:approved_relationship, named: :approved, actor: actor, object: object5)

          it "omits unapproved replies but includes their approved children" do
            expect(subject.thread(approved_by: actor)).to eq([subject, object5])
          end

          it "doesn't include the actor's unapproved replies" do
            object4.assign(attributed_to: actor).save
            expect(subject.thread(approved_by: actor)).to eq([subject, object5])
          end

          it "doesn't include non-visible replies even when approved" do
            object5.assign(visible: false).save
            expect(subject.thread(approved_by: actor)).not_to contain(object5)
          end
        end
      end
    end

    describe "#thread_query" do
      let_build(:actor)

      let(projection) { {id: Int64, iri: String, depth: Int32} }

      it "returns projection fields" do
        result = subject.thread_query(projection: projection)
        expect(result.size).to eq(6)
        first = result.first
        expect(first[:id]).to eq(subject.id)
        expect(first[:iri]).to eq(subject.iri)
        expect(first[:depth]).to eq(0)
      end

      it "returns the same objects in the same order as `thread`" do
        result1 = subject.thread_query(projection: projection)
        result2 = subject.thread(for_actor: actor)
        expect(result1.size).to eq(result2.size)
        expect(result1.map { |r| r[:id] }).to eq(result2.map(&.id))
        expect(result1.map { |r| r[:iri] }).to eq(result2.map(&.iri))
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        result = subject.thread_query(projection: projection)
        expect(result.size).to eq(4)
        expect(result.map { |r| r[:iri] }).to eq([subject, object1, object2, object3].map(&.iri))
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        result = subject.thread_query(projection: projection)
        expect(result.size).to eq(4)
        expect(result.map { |r| r[:iri] }).to eq([subject, object1, object2, object3].map(&.iri))
      end

      it "includes deleted status for non-deleted objects" do
        result = subject.thread_query(projection: {deleted: Bool})
        expect(result[1][:deleted]).to be_false
      end

      context "given a deleted object" do
        before_each { object1.delete! }

        it "includes deleted status for deleted objects" do
          result = subject.thread_query(projection: {deleted: Bool})
          expect(result[1][:deleted]).to be_true
        end
      end

      it "includes blocked status for non-blocked objects" do
        result = subject.thread_query(projection: {blocked: Bool})
        expect(result[1][:blocked]).to be_false
      end

      context "given a blocked object" do
        before_each { object1.block! }

        it "includes blocked status for blocked objects" do
          result = subject.thread_query(projection: {blocked: Bool})
          expect(result[1][:blocked]).to be_true
        end
      end

      it "returns nil for hashtags" do
        result = subject.thread_query(projection: {hashtags: String?})
        expect(result[1][:hashtags]).to be_nil
      end

      context "given hashtags" do
        let_create!(:hashtag, named: nil, subject: object1, name: "foo")
        let_create!(:hashtag, named: nil, subject: object1, name: "bar")

        it "includes hashtags" do
          result = subject.thread_query(projection: {hashtags: String?})
          expect(result[1][:hashtags].try(&.split(",").sort)).to eq(["bar", "foo"])
        end
      end

      it "returns nil for mentions" do
        result = subject.thread_query(projection: {mentions: String?})
        expect(result[1][:mentions]).to be_nil
      end

      context "given mentions" do
        let_create!(:mention, named: nil, subject: object1, name: "alice@example.com")
        let_create!(:mention, named: nil, subject: object1, name: "bob@example.com")

        it "includes mentions" do
          result = subject.thread_query(projection: {mentions: String?})
          expect(result[1][:mentions].try(&.split(",").sort)).to eq(["alice@example.com", "bob@example.com"])
        end
      end
    end

    describe "#ancestors" do
      it "returns all ancestors" do
        expect(subject.ancestors).to eq([subject])
        expect(object3.ancestors).to eq([object3, object2, object1, subject])
        expect(object5.ancestors).to eq([object5, object4, subject])
      end

      it "omits deleted replies and their parents" do
        object1.delete!
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits blocked replies and their parents" do
        object1.block!
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits destroyed replies and their parents" do
        object1.destroy
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits replies with deleted attributed to actors" do
        actor1.delete!
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits replies with blocked attributed to actors" do
        actor1.block!
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits replies with destroyed attributed to actors" do
        actor1.destroy
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "returns the depths" do
        expect(object5.ancestors.map(&.depth)).to eq([0, 1, 2])
      end

      context "given an actor" do
        let_build(:actor)

        it "only includes the subject" do
          expect(object5.ancestors(actor)).to eq([subject])
        end

        context "and an approved object" do
          let_create!(:approved_relationship, named: :approved, actor: actor, object: object5)

          it "omits unapproved replies but includes their approved parents" do
            expect(object5.ancestors(actor)).to eq([object5, subject])
          end

          it "doesn't include the actor's unapproved replies" do
            object4.assign(attributed_to: actor).save
            expect(object5.ancestors(actor)).to eq([object5, subject])
          end
        end
      end
    end
  end

  describe "#analyze_thread" do
    let_build(:actor)
    let(base_time) { Time.utc(2025, 1, 1, 10, 0) }

    def make_test_thread(structure : Array({time_offset: Time::Span, parent_idx: Int32?, author_idx: Int32}))
      actors = (0...6).map do |i|
        Factory.create(:actor, iri: "https://test.test/actors/#{('a'.ord + i).chr}")
      end
      objects = [] of ActivityPub::Object
      structure.each do |spec|
        parent = (idx = spec[:parent_idx]) ? objects[idx] : nil
        object = Factory.create(
          :object,
          in_reply_to: parent,
          attributed_to: actors[spec[:author_idx]],
          published: base_time + spec[:time_offset]
        )
        objects << object
      end
      objects.first
    end

    context "with small test thread" do
      let(root) do
        make_test_thread([
          {time_offset: 0.minutes, parent_idx: nil, author_idx: 0},    # root by author_a
          {time_offset: 5.minutes, parent_idx: 0, author_idx: 1},      # reply1 by author_b
          {time_offset: 10.minutes, parent_idx: 1, author_idx: 2},     # branch_reply1 by author_c
          {time_offset: 15.minutes, parent_idx: 1, author_idx: 3},     # branch_reply2 by author_d
          {time_offset: 20.minutes, parent_idx: 1, author_idx: 4},     # branch_reply3 by author_e
          {time_offset: 25.minutes, parent_idx: 1, author_idx: 5},     # branch_reply4 by author_f
          {time_offset: 30.minutes, parent_idx: 1, author_idx: 0},     # branch_reply5 by author_a (OP)
        ])
      end

      subject { root.analyze_thread(for_actor: actor) }

      it "includes basic statistics" do
        expect(subject.object_count).to eq(7)
        expect(subject.author_count).to eq(6)
        expect(subject.max_depth).to eq(2)
      end

      it "includes thread_id" do
        expect(subject.thread_id).to eq(root.thread)
      end

      it "includes root_object_id" do
        expect(subject.root_object_id).to eq(root.id)
      end

      it "includes key_participants" do
        expect(subject.key_participants.first.actor_iri).to eq(root.attributed_to_iri)
      end

      it "includes notable_branches" do
        expect(subject.notable_branches.size).to eq(1)
      end

      it "includes timeline_histogram" do
        expect(subject.timeline_histogram.not_nil!.total_objects).to eq(7)
      end
    end
  end

  describe "#activities" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      )
    end

    macro activity(index)
      let_create(:actor, named: actor{{index}})
      let_create!(
        :activity, named: activity{{index}},
        actor_iri: actor{{index}}.iri,
        object_iri: subject.iri,
      )
    end

    activity(1)
    activity(2)
    activity(3)

    let_build(:like, actor: actor1, object: subject)

    it "returns the associated activities" do
      expect(subject.activities).to eq([activity1, activity2, activity3])
    end

    context "given a like" do
      before_each { like.save }

      it "includes only activities of the specified class" do
        expect(subject.activities(inclusion: ActivityPub::Activity::Like)).to eq([like])
      end

      it "excludes all activities of the specified class" do
        expect(subject.activities(exclusion: ActivityPub::Activity::Like)).to eq([activity1, activity2, activity3])
      end
    end

    it "filters out undone activities" do
      activity1.undo!
      expect(subject.activities).to eq([activity2, activity3])
    end

    it "filters out activities of deleted actors" do
      actor1.delete!
      expect(subject.activities).to eq([activity2, activity3])
    end

    it "filters out activities of blocked actors" do
      actor1.block!
      expect(subject.activities).to eq([activity2, activity3])
    end
  end

  describe "#approved_by?" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      )
    end

    let_build(:actor)
    let_create!(:approved_relationship, named: :approved, actor: actor, object: subject)

    it "returns true if approved by actor" do
      expect(subject.approved_by?(actor.iri)).to be_true
    end

    it "returns false if not approved by actor" do
      expect(subject.approved_by?("https://other/")).to be_false
    end
  end

  describe "#external?" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      ).save
    end

    it "returns true" do
      expect(subject.external?).to be_true
    end
  end

  describe "#root?" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      ).save
    end

    it "returns true if root" do
      expect(subject.root?).to be_true
    end

    it "returns false if a reply" do
      expect(subject.assign(in_reply_to_iri: "https://root").root?).to be_false
    end

    it "returns false if not root" do
      expect(subject.assign(thread: "https://root").root?).to be_false
    end
  end

  describe "#draft?" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      ).save
    end

    it "returns true if draft" do
      expect(subject.draft?).to be_true
    end

    it "returns false if not local" do
      expect(subject.assign(iri: "https://remote/object").draft?).to be_false
    end

    it "returns false if published" do
      expect(subject.assign(published: Time.utc).draft?).to be_false
    end
  end

  context "canonical path" do
    PATH = "/abc/xyz"

    subject do
      described_class.new(
        iri: "https://test.test#{PATH}"
      )
    end

    let_build(:canonical_relationship, named: :canonical, from_iri: "/foo/bar/baz", to_iri: PATH)

    before_all do
      Kemal::RouteHandler::INSTANCE.add_route("GET", PATH) { }
    end

    describe "#canonical_path" do
      it "returns nil by default" do
        expect(subject.canonical_path).to be_nil
      end

      context "given an existing canonical relationship" do
        before_each { canonical.save }

        it "returns the canonical path" do
          expect(subject.canonical_path).to eq("/foo/bar/baz")
        end
      end
    end

    context "given an existing canonical relationship" do
      before_each { canonical.save }

      describe "#save" do
        it "doesn't destroy the canonical path" do
          subject.save
          expect(subject.reload!.canonical_path).not_to be_nil
        end
      end
    end

    describe "#canonical_path=" do
      it "assigns a new canonical path" do
        subject.assign(canonical_path: "/foo/bar/baz").save
        expect(subject.reload!.canonical_path).to eq("/foo/bar/baz")
      end

      it "adds the canonical path to urls" do
        subject.assign(canonical_path: "/foo/bar/baz").save
        expect(subject.reload!.urls).to eq(["https://test.test/foo/bar/baz"])
      end

      context "given an existing canonical relationship" do
        before_each { subject.assign(canonical_path: "/foo/bar/baz").save }

        it "updates the canonical path" do
          subject.assign(canonical_path: "/blarg/blarg").save
          expect(subject.reload!.canonical_path).to eq("/blarg/blarg")
        end

        it "adds the canonical path to urls" do
          subject.assign(canonical_path: "/blarg/blarg").save
          expect(subject.reload!.urls).to eq(["https://test.test/blarg/blarg"])
        end

        it "removes the canonical path" do
          subject.assign(canonical_path: nil).save
          expect(subject.reload!.canonical_path).to be_nil
        end

        it "removes the canonical path from urls" do
          subject.assign(canonical_path: nil).save
          expect(subject.reload!.urls).to be_empty
        end
      end

      context "given existing urls" do
        before_each { subject.assign(urls: ["https://test.test/url"]).save }

        it "adds the canonical URL to the urls" do
          subject.assign(canonical_path: "/foo/bar/baz").save
          expect(subject.reload!.urls).to eq(["https://test.test/url", "https://test.test/foo/bar/baz"])
        end
      end
    end

    describe "#delete" do
      before_each { canonical.save }

      it "destroys the associated canonical path" do
        expect{subject.delete!}.to change{subject.canonical_path}
      end
    end

    describe "#destroy" do
      before_each { canonical.save }

      it "destroys the associated canonical path" do
        expect{subject.destroy}.to change{subject.canonical_path}
      end
    end
  end

  describe "#tags" do
    let(hashtag) { Factory.build(:hashtag, name: "foo", href: "https://test.test/tags/foo") }
    let(mention) { Factory.build(:mention, name: "foo@test.test", href: "https://test.test/actors/foo") }
    subject do
      described_class.new(
        iri: "https://test.test/object",
        hashtags: [hashtag],
        mentions: [mention]
      )
    end

    it "returns tags" do
      expect(subject.tags).to contain_exactly(hashtag, mention)
    end
  end

  describe "#preview" do
    let_build(:object, summary: nil, content: nil)

    it "returns nil" do
      expect(object.preview).to be_nil
    end

    context "with content" do
      before_each { object.assign(content: "original content") }

      it "returns content" do
        expect(object.preview).to eq("original content")
      end

      context "and content translation" do
        let_create!(:translation, origin: object, content: "translated content")

        it "returns content translation" do
          expect(object.preview).to eq("translated content")
        end

        context "and summary" do
          before_each { object.assign(summary: "original summary") }

          it "returns summary" do
            expect(object.preview).to eq("original summary")
          end

          context "and summary translation" do
            let_create!(:translation, origin: object, summary: "translated summary")

            it "returns summary translation" do
              expect(object.preview).to eq("translated summary")
            end
          end
        end
      end
    end

    context "with multiple translations" do
      before_each { object.assign(summary: "original summary", content: "original content") }

      let_create!(:translation, named: nil, origin: object, summary: "first translated summary", content: "first translated content")
      let_create!(:translation, named: nil, origin: object, summary: "second translated summary", content: "second translated content")

      it "uses most recent translation" do
        expect(object.preview).to eq("second translated summary")
      end
    end

    context "with blank values" do
      before_each { object.assign(summary: nil, content: "original content") }

      let_create!(:translation, origin: object, summary: "", content: "  ")

      it "ignores blank values" do
        expect(object.preview).to eq("original content")
      end
    end
  end
end

Spectator.describe ActivityPub::Object::ModelHelper do
  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://test.test/object",
        "@type":"FooBarObject",
        "replies":{
          "@id":"replies link",
          "@type":"Collection"
        }
      }
    JSON
  end

  describe ".from_json_ld" do
    let(object) { described_class.from_json_ld(json) }

    it "populates replies_iri" do
      expect(object["replies_iri"]).to eq("replies link")
    end

    it "does not populate replies" do
      expect(object.has_key?("replies")).to be_false
    end

    context "given a replies collection with the same host" do
      let(json) { super.gsub(%q|"@id":"replies link",|, %q|"@id":"https://test.test/replies",|) }

      it "populates replies" do
        expect(object["replies"]).to be_a(ActivityPub::Collection)
        expect(object["replies"].as(ActivityPub::Collection).iri).to eq("https://test.test/replies")
      end
    end

    context "given object without an id" do  # should never happen, but...
      let(json) { super.gsub(%q|"@id":"replies link",|, %q|"@id":"https://test.test/replies",|).gsub(%q|"@id":"https://test.test/object",|, "") }

      it "does not populate replies" do
        expect(object.has_key?("replies")).to be_false
      end
    end

    context "given replies with a different host" do
      let(json) { super.gsub(%q|"@id":"replies link",|, %q|"id":"https://different/replies",|) }

      it "does not populate replies" do
        expect(object.has_key?("replies")).to be_false
      end
    end

    context "given replies without an id" do
      let(json) { super.gsub(%q|"@id":"replies link",|, "") }

      it "populates replies" do
        expect(object["replies"]).to be_a(ActivityPub::Collection)
      end
    end
  end
end

Spectator.describe ActivityPub::Object::Attachment do
  def create_attachment(focal_point : Tuple(Float64, Float64)? = nil)
    ActivityPub::Object::Attachment.new(
      "https://example.com/image.jpg",
      "image/jpeg",
      nil,
      focal_point
    )
  end

  describe "#has_focal_point?" do
    it "returns false for missing focal point" do
      attachment = create_attachment

      expect(attachment.has_focal_point?).to be_false
    end

    it "returns true for valid position" do
      attachment = create_attachment({0.0, 0.0})

      expect(attachment.has_focal_point?).to be_true
    end

    it "returns true for valid positions" do
      attachment = create_attachment({-0.6, 0.07})

      expect(attachment.has_focal_point?).to be_true
    end
  end

  describe "#normalized_focal_point" do
    it "converts Mastodon coordinates" do
      attachment = create_attachment({0.2, -0.4})

      normalized = attachment.normalized_focal_point.not_nil!
      # with exaggeration (strength=0.75):
      expect(normalized[0]).to be_within(0.001).of(0.6778)
      expect(normalized[1]).to be_within(0.001).of(0.7990)
    end
  end

  describe "#css_object_position" do
    it "generates correct CSS values" do
      attachment = create_attachment({0.2, -0.4})

      css = attachment.css_object_position
      expect(css).to eq("67.78% 79.91%")
    end

    it "returns center fallback when no focal point" do
      attachment = create_attachment

      css = attachment.css_object_position
      expect(css).to eq("50% 50%")
    end
  end
end
