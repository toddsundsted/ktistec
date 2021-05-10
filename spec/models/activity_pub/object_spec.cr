require "../../../src/models/activity_pub/object"
require "../../../src/models/activity_pub/activity/announce"
require "../../../src/models/activity_pub/activity/like"

require "../../spec_helper/model"

class FooBarObject < ActivityPub::Object
end

Spectator.describe ActivityPub::Object do
  setup_spec

  describe "#source=" do
    subject { described_class.new(iri: "https://test.test/objects/#{random_string}") }
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

    context "addressing (to)" do
      before_each do
        foo = ActivityPub::Actor.new(
          iri: "https://bar.com/foo",
          urls: ["https://bar.com/@foo"],
          username: "foo"
        ).save
        bar = ActivityPub::Actor.new(
          iri: "https://foo.com/bar",
          urls: ["https://foo.com/@bar"],
          username: "bar"
        ).save
        Tag::Mention.new(
          subject: subject,
          href: "https://foo.com/bar",
          name: "bar"
        ).save
      end

      it "replaces mentions" do
        subject.assign(to: ["https://test.test/actor", "https://foo.com/bar"], source: source).save
        expect(subject.to).to eq(["https://test.test/actor", "https://bar.com/foo"])
      end
    end
  end

  context "when validating" do
    subject { described_class.new(iri: "https://test.test/#{random_string}") }

    it "returns false if the canonical path is not valid" do
      expect(subject.assign(canonical_path: "foobar").valid?).to be_false
    end

    it "is valid" do
      expect(subject.valid?).to be_true
    end
  end

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://remote/foo_bar",
        "@type":"FooBarObject",
        "published":"2016-02-15T10:20:30Z",
        "attributedTo":{
          "id":"attributed to link"
        },
        "inReplyTo":"in reply to link",
        "replies":{
          "id":"replies link"
        },
        "to":"to link",
        "cc":["cc link"],
        "summary":"abc",
        "content":"abc",
        "mediaType":"xyz",
        "attachment":[
          {
            "url":"attachment link",
            "mediaType":"type"
          }
        ],
        "url":"url link"
      }
    JSON
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
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type")])
      expect(object.urls).to eq(["url link"])
    end

    context "when addressed to the public collection" do
      it "is visible" do
        json = self.json.gsub("to link", "https://www.w3.org/ns/activitystreams#Public")
        object = described_class.from_json_ld(json).save
        expect(object.visible).to be_true
      end
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      object = described_class.new.from_json_ld(json).save
      expect(object.iri).to eq("https://remote/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type")])
      expect(object.urls).to eq(["url link"])
    end

    context "when addressed to the public collection" do
      it "is visible" do
        json = self.json.gsub("cc link", "https://www.w3.org/ns/activitystreams#Public")
        object = described_class.new.from_json_ld(json).save
        expect(object.visible).to be_true
      end
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      object = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(object.to_json_ld)).to eq(object)
    end

    it "renders hashtags" do
      object = described_class.new(
        iri: "https://test.test/object",
        hashtags: [Tag::Hashtag.new(name: "foo", href: "https://test.test/tags/foo")]
      ).save
      expect(JSON.parse(object.to_json_ld).dig("tag").as_a).to contain_exactly({"type" => "Hashtag", "name" => "#foo", "href" => "https://test.test/tags/foo"})
    end

    it "renders mentions" do
      object = described_class.new(
        iri: "https://test.test/object",
        mentions: [Tag::Mention.new(name: "foo@test.test", href: "https://test.test/actors/foo")]
      ).save
      expect(JSON.parse(object.to_json_ld).dig("tag").as_a).to contain_exactly({"type" => "Mention", "name" => "@foo@test.test", "href" => "https://test.test/actors/foo"})
    end
  end

  describe "#make_delete_activity" do
    let(attributed_to) do
      ActivityPub::Actor.new(
        iri: "https://test.test/objects/actor"
      )
    end
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
      let!(post{{index}}) do
        ActivityPub::Object.new(
          iri: "https://test.test/objects/#{random_string}",
          published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
          visible: {{index}}.odd?
        ).save
      end
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

    it "instantiates the correct subclass" do
      expect(described_class.federated_posts(1, 2).first).to be_a(ActivityPub::Object)
    end

    it "filters out non-public posts" do
      expect(described_class.federated_posts(1, 2)).to eq([post5, post3])
    end

    it "filters out deleted posts" do
      post5.delete
      expect(described_class.federated_posts(1, 2)).to eq([post3, post1])
    end

    it "paginates the results" do
      expect(described_class.federated_posts(1, 2)).to eq([post5, post3])
      expect(described_class.federated_posts(2, 2)).to eq([post1])
      expect(described_class.federated_posts(2, 2).more?).not_to be_true
    end
  end

  describe "#with_statistics!" do
    let(object) do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      )
    end
    let(announce) do
      ActivityPub::Activity::Announce.new(
        iri: "https://test.test/announce",
        object: object
      )
    end
    let(like) do
      ActivityPub::Activity::Like.new(
        iri: "https://test.test/like",
        object: object
      )
    end

    it "updates announces count" do
      announce.save
      expect(object.with_statistics!.announces_count).to eq(1)
      expect(object.with_statistics!.likes_count).to eq(0)
    end

    it "updates likes count" do
      like.save
      expect(object.with_statistics!.announces_count).to eq(0)
      expect(object.with_statistics!.likes_count).to eq(1)
    end

    it "doesn't fail when the object hasn't been saved" do
      expect(object.with_statistics!.announces_count).to eq(0)
      expect(object.with_statistics!.likes_count).to eq(0)
    end
  end

  context "when threaded" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}",
        attributed_to: ActivityPub::Actor.new(
          iri: "https://test.test/actors/#{random_string}",
        )
      ).save
    end

    macro reply_to!(object, reply)
      {% actor = reply.name.gsub(/object/, "actor") %}
      let({{actor}}) do
        ActivityPub::Actor.new(
          iri: "https://test.test/actors/#{random_string}"
        ).save
      end
      let!({{reply}}) do
        described_class.new(
          iri: "https://test.test/objects/#{random_string}",
          attributed_to: {{actor}},
          in_reply_to: {{object}}
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

    let(announce) do
      ActivityPub::Activity::Announce.new(
        iri: "https://test.test/announce",
        object: object2
      )
    end
    let(like) do
      ActivityPub::Activity::Like.new(
        iri: "https://test.test/like",
        object: object5
      )
    end

    describe "#with_replies_count!" do
      it "returns the count of replies" do
        expect(subject.with_replies_count!.replies_count).to eq(5)
        expect(object5.with_replies_count!.replies_count).to eq(0)
      end

      it "omits deleted replies and their children" do
        object4.delete
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits replies with deleted attributed to actors" do
        actor4.delete
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        expect(subject.with_replies_count!.replies_count).to eq(3)
      end

      context "given an actor" do
        let(actor) do
          ActivityPub::Actor.new(
            iri: "https://test.test/#{random_string}"
          )
        end

        it "doesn't count any replies" do
          expect(subject.with_replies_count!(actor).replies_count).to eq(0)
        end

        context "and an approved object" do
          let!(approved) do
            Relationship::Content::Approved.new(
              actor: actor,
              object: object5
            ).save
          end

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

    describe "#thread" do
      it "returns all replies properly nested" do
        expect(subject.thread).to eq([subject, object1, object2, object3, object4, object5])
        expect(object1.thread).to eq([subject, object1, object2, object3, object4, object5])
        expect(object5.thread).to eq([subject, object1, object2, object3, object4, object5])
      end

      it "omits deleted replies and their children" do
        object4.delete
        expect(subject.thread).to eq([subject, object1, object2, object3])
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        expect(subject.thread).to eq([subject, object1, object2, object3])
      end

      it "omits replies with deleted attributed to actors" do
        actor4.delete
        expect(subject.thread).to eq([subject, object1, object2, object3])
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        expect(subject.thread).to eq([subject, object1, object2, object3])
      end

      it "returns the depths" do
        expect(object5.thread.map(&.depth)).to eq([0, 1, 2, 3, 1, 2])
      end

      context "given an actor" do
        let(actor) do
          ActivityPub::Actor.new(
            iri: "https://test.test/#{random_string}"
          )
        end

        it "only includes the subject" do
          expect(subject.thread(actor)).to eq([subject])
        end

        context "and an approved object" do
          let!(approved) do
            Relationship::Content::Approved.new(
              actor: actor,
              object: object5
            ).save
          end

          it "omits unapproved replies but includes their approved children" do
            expect(subject.thread(actor)).to eq([subject, object5])
          end

          it "doesn't include the actor's unapproved replies" do
            object4.assign(attributed_to: actor).save
            expect(subject.thread(actor)).to eq([subject, object5])
          end
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
        object1.delete
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits destroyed replies and their parents" do
        object1.destroy
        expect(object3.ancestors).to eq([object3, object2])
      end

      it "omits replies with deleted attributed to actors" do
        actor1.delete
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
        let(actor) do
          ActivityPub::Actor.new(
            iri: "https://test.test/#{random_string}"
          )
        end

        it "only includes the subject" do
          expect(object5.ancestors(actor)).to eq([subject])
        end

        context "and an approved object" do
          let!(approved) do
            Relationship::Content::Approved.new(
              actor: actor,
              object: object5
            ).save
          end

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

  describe "#approved_by?" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}"
      )
    end
    let(actor) do
      ActivityPub::Actor.new(
        iri: "https://test.test/#{random_string}"
      )
    end
    let!(approved) do
      Relationship::Content::Approved.new(
        actor: actor,
        object: subject
      ).save
    end

    it "returns true if approved by actor" do
      expect(subject.approved_by?(actor.iri)).to be_true
    end

    it "returns false if not approved by actor" do
      expect(subject.approved_by?("https://other/")).to be_false
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
    let(canonical) do
      Relationship::Content::Canonical.new(
        from_iri: "/foo/bar/baz",
        to_iri: PATH
      )
    end

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
          expect(described_class.find(subject.id).canonical_path).not_to be_nil
        end
      end
    end

    describe "#canonical_path=" do
      it "assigns a new canonical path" do
        subject.assign(canonical_path: "/foo/bar/baz").save
        expect(described_class.find(subject.id).canonical_path).to eq("/foo/bar/baz")
      end

      it "adds the canonical path to urls" do
        subject.assign(canonical_path: "/foo/bar/baz").save
        expect(described_class.find(subject.id).urls).to eq(["https://test.test/foo/bar/baz"])
      end

      context "given an existing canonical relationship" do
        before_each { subject.assign(canonical_path: "/foo/bar/baz").save }

        it "updates the canonical path" do
          subject.assign(canonical_path: "/blarg/blarg").save
          expect(described_class.find(subject.id).canonical_path).to eq("/blarg/blarg")
        end

        it "adds the canonical path to urls" do
          subject.assign(canonical_path: "/blarg/blarg").save
          expect(described_class.find(subject.id).urls).to eq(["https://test.test/blarg/blarg"])
        end

        it "removes the canonical path" do
          subject.assign(canonical_path: nil).save
          expect(described_class.find(subject.id).canonical_path).to be_nil
        end

        it "removes the canonical path from urls" do
          subject.assign(canonical_path: nil).save
          expect(described_class.find(subject.id).urls).to be_empty
        end
      end

      context "given existing urls" do
        before_each { subject.assign(urls: ["https://test.test/url"]).save }

        it "adds the canonical URL to the urls" do
          subject.assign(canonical_path: "/foo/bar/baz").save
          expect(described_class.find(subject.id).urls).to eq(["https://test.test/url", "https://test.test/foo/bar/baz"])
        end
      end
    end

    describe "#delete" do
      before_each { canonical.save }

      it "destroys the associated canonical path" do
        expect{subject.delete}.to change{subject.canonical_path}
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
    let(hashtag) { Tag::Hashtag.new(name: "foo", href: "https://test.test/tags/foo") }
    let(mention) { Tag::Mention.new(name: "foo@test.test", href: "https://test.test/actors/foo") }
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
end
