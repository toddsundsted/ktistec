require "../../../src/models/activity_pub/object"
require "../../../src/models/activity_pub/activity/announce"
require "../../../src/models/activity_pub/activity/like"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class FooBarObject < ActivityPub::Object
end

Spectator.describe ActivityPub::Object do
  setup_spec

  describe "#source=" do
    subject { described_class.new(iri: "https://test.test/objects/#{random_string}") }
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

    context "addressing (to)" do
      let_create!(:mention, subject: subject, href: bar.iri, name: bar.username)

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
          "https://www.w3.org/ns/activitystreams",
          {"Hashtag":"as:Hashtag"}
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
        "name":"123",
        "summary":"abc",
        "content":"abc",
        "mediaType":"xyz",
        "tag":[
          {"type":"Hashtag","href":"hashtag href","name":"#hashtag"},
          {"type":"Mention","href":"mention href","name":"@mention"}
        ],
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
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.name).to eq("123")
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.hashtags.first).to match(Tag::Hashtag.new(name: "hashtag", href: "hashtag href"))
      expect(object.mentions.first).to match(Tag::Mention.new(name: "mention", href: "mention href"))
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
      expect(object.name).to eq("123")
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.hashtags.first).to match(Tag::Hashtag.new(name: "hashtag", href: "hashtag href"))
      expect(object.mentions.first).to match(Tag::Mention.new(name: "mention", href: "mention href"))
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
  end

  describe ".public_posts" do
    let(actor) { register.actor }

    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: post{{index}}, attributed_to: actor{{index}})
      let_build(:announce, named: activity{{index}}, actor: actor, object: post{{index}})
      let_create!(
        :outbox_relationship, named: relationship{{index}},
        owner: actor,
        activity: activity{{index}}
      )
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

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

    it "includes posts only once" do
      outbox.save
      expect(described_class.public_posts(1, 2)).to eq([post5, post4])
    end

    it "paginates the results" do
      expect(described_class.public_posts(1, 2)).to eq([post5, post4])
      expect(described_class.public_posts(3, 2)).to eq([post1])
      expect(described_class.public_posts(3, 2).more?).not_to be_true
    end
  end

  describe ".public_posts_count" do
    let(actor) { register.actor }

    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: post{{index}}, attributed_to: actor{{index}})
      let_build(:announce, named: activity{{index}}, actor: actor, object: post{{index}})
      let_create!(
        :outbox_relationship, named: relationship{{index}},
        owner: actor,
        activity: activity{{index}}
      )
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

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

    it "counts posts only once" do
      outbox.save
      expect(described_class.public_posts_count).to eq(5)
    end

    it "returns the count" do
      expect(described_class.public_posts_count).to eq(5)
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

    it "filters out undone announces" do
      announce.save.undo!
      expect(object.with_statistics!.announces_count).to eq(0)
    end

    it "filters out undone likes" do
      like.save.undo!
      expect(object.with_statistics!.likes_count).to eq(0)
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

    context "given a follow" do
      let_create(:actor)
      let_create!(:follow_thread_relationship, named: nil, actor: actor, thread: object.save.thread)

      def all_follows ; Relationship::Content::Follow::Thread.all end

      it "updates follow relationships when thread changes" do
        expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_follows.map(&.to_iri)}.to(["https://elsewhere"])
      end

      context "given an existing follow relationship" do
        let_create!(:follow_thread_relationship, named: nil, actor: actor, thread: "https://elsewhere")

        it "updates follow relationships when thread changes" do
          expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_follows.map(&.to_iri)}.to(["https://elsewhere"])
        end
      end
    end
  end

  context "when threaded" do
    subject do
      described_class.new(
        iri: "https://test.test/objects/#{random_string}",
        attributed_to: Factory.build(:actor)
      ).save
    end

    macro reply_to!(object, reply)
      {% actor = reply.name.gsub(/object/, "actor") %}
      let_create(:actor, named: {{actor}})
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

    describe "#thread" do
      let_build(:actor)

      it "returns all replies properly nested" do
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5])
        expect(object1.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5])
        expect(object5.thread(for_actor: actor)).to eq([subject, object1, object2, object3, object4, object5])
      end

      it "omits deleted replies and their children" do
        object4.delete!
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "omits blocked replies and their children" do
        object4.block!
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "omits replies with deleted attributed to actors" do
        actor4.delete!
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "omits replies with blocked attributed to actors" do
        actor4.block!
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "omits replies with destroyed attributed to actors" do
        actor4.destroy
        expect(subject.thread(for_actor: actor)).to eq([subject, object1, object2, object3])
      end

      it "returns the depths" do
        expect(object5.thread(for_actor: actor).map(&.depth)).to eq([0, 1, 2, 3, 1, 2])
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
end
