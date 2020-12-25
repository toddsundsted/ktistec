require "../../../src/models/activity_pub/actor"
require "../../../src/models/activity_pub/activity/like"
require "../../../src/models/activity_pub/object/note"

require "../../spec_helper/model"

class FooBarActor < ActivityPub::Actor
end

Spectator.describe ActivityPub::Actor do
  setup_spec

  let(username) { random_string }
  let(password) { random_string }

  let(foo_bar) do
    FooBarActor.new(
      iri: "https://test.test/#{random_string}",
      pem_public_key: (<<-KEY
        -----BEGIN PUBLIC KEY-----
        MFowDQYJKoZIhvcNAQEBBQADSQAwRgJBAKr1/30vwtQozUzKAiM87+cJzUvA15KR
        KNFcMekDexfrLUk8EjP0psKcm9AGVefYvfKtD2cAGhF6UTZKVUUZRmECARE=
        -----END PUBLIC KEY-----
        KEY
      ),
      pem_private_key: (<<-KEY
        -----BEGIN PRIVATE KEY-----
        MIIBUQIBADANBgkqhkiG9w0BAQEFAASCATswggE3AgEAAkEAqvX/fS/C1CjNTMoC
        Izzv5wnNS8DXkpEo0Vwx6QN7F+stSTwSM/Smwpyb0AZV59i98q0PZwAaEXpRNkpV
        RRlGYQIBEQJAHitpUlO4+ENvhgWH6BnP+5hRZ7ieg0bK98T5v7VR9Sk2e/9cHRsj
        kEztFNLNvWRiib1JWyP3f8uXbmnLsTQtMQIhAN6PLZn4nssJ0j2pv5jnhYKInq/g
        Y85JWNP0s0K8c/15AiEAxKYSGOu8EjHBHrBG2c8aYl2IaoIl0UlKeHqU5Zx9nikC
        IFukXhI5MlOaod0nx10UCcxWX3WYoZEtQrGg/oTkL8K5AiAXIpi3o0NNb0PlfiZz
        +j9W3dPQS4v6gRfR8E3AqP+4QQIgEnP6htV+XMD4H9zg9aG+GFDorjWctnpNR6Z7
        +4EIKbQ=
        -----END PRIVATE KEY-----
        KEY
      )
    ).save
  end

  describe "#public_key" do
    it "returns the public key" do
      expect(foo_bar.public_key).to be_a(OpenSSL::RSA)
    end
  end

  describe "#private_key" do
    it "returns the private key" do
      expect(foo_bar.private_key).to be_a(OpenSSL::RSA)
    end
  end

  context "when using the keypair" do
    it "verifies the signed message" do
      message = "this is a test"
      private_key = foo_bar.private_key
      public_key = foo_bar.public_key
      if private_key && public_key
        signature = private_key.sign(OpenSSL::Digest.new("SHA256"), message)
        expect(public_key.verify(OpenSSL::Digest.new("SHA256"), signature, message)).to be_true
      end
    end
  end

  context "when validating" do
    it "is valid" do
      expect(described_class.new(iri: "http://test.test/#{random_string}").valid?).to be_true
    end
  end

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams",
          "https://w3id.org/security/v1"
        ],
        "@id":"https://test.test/foo_bar",
        "@type":"FooBarActor",
        "preferredUsername":"foo_bar",
        "publicKey":{
          "id":"https://test.test/foo_bar#public-key",
          "owner":"https://test.test/foo_bar",
          "publicKeyPem":"---PEM PUBLIC KEY---"
        },
        "inbox": "inbox link",
        "outbox": "outbox link",
        "following": "following link",
        "followers": "followers link",
        "name":"Foo Bar",
        "summary": "<p></p>",
        "icon": {
          "type": "Image",
          "mediaType": "image/jpeg",
          "url": "icon link"
        },
        "image": {
          "type": "Image",
          "mediaType": "image/jpeg",
          "url": "image link"
        },
        "url":"url link"
      }
    JSON
  end

  describe ".from_json_ld" do
    it "instantiates the subclass" do
      actor = described_class.from_json_ld(json)
      expect(actor.class).to eq(FooBarActor)
    end

    it "creates a new instance" do
      actor = described_class.from_json_ld(json).save
      expect(actor.iri).to eq("https://test.test/foo_bar")
      expect(actor.username).to eq("foo_bar")
      expect(actor.pem_public_key).to be_nil
      expect(actor.inbox).to eq("inbox link")
      expect(actor.outbox).to eq("outbox link")
      expect(actor.following).to eq("following link")
      expect(actor.followers).to eq("followers link")
      expect(actor.name).to eq("Foo Bar")
      expect(actor.summary).to eq("<p></p>")
      expect(actor.icon).to eq("icon link")
      expect(actor.image).to eq("image link")
      expect(actor.urls).to eq(["url link"])
    end

    it "includes the public key" do
      actor = described_class.from_json_ld(json, include_key: true).save
      expect(actor.pem_public_key).to eq("---PEM PUBLIC KEY---")
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      actor = described_class.new.from_json_ld(json).save
      expect(actor.iri).to eq("https://test.test/foo_bar")
      expect(actor.username).to eq("foo_bar")
      expect(actor.pem_public_key).to be_nil
      expect(actor.inbox).to eq("inbox link")
      expect(actor.outbox).to eq("outbox link")
      expect(actor.following).to eq("following link")
      expect(actor.followers).to eq("followers link")
      expect(actor.name).to eq("Foo Bar")
      expect(actor.summary).to eq("<p></p>")
      expect(actor.icon).to eq("icon link")
      expect(actor.image).to eq("image link")
      expect(actor.urls).to eq(["url link"])
    end

    it "includes the public key" do
      actor = described_class.new.from_json_ld(json, include_key: true).save
      expect(actor.pem_public_key).to eq("---PEM PUBLIC KEY---")
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      actor = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(actor.to_json_ld)).to eq(actor)
    end
  end

  describe "#follow" do
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    it "adds a public following relationship" do
      foo_bar.follow(other, confirmed: true, visible: true).save
      expect(foo_bar.all_following(public: true)).to eq([other])
      expect(foo_bar.all_following(public: false)).to eq([other])
    end

    it "adds a public followers relationship" do
      other.follow(foo_bar, confirmed: true, visible: true).save
      expect(foo_bar.all_followers(public: true)).to eq([other])
      expect(foo_bar.all_followers(public: false)).to eq([other])
    end

    it "adds a non-public following relationship" do
      foo_bar.follow(other).save
      expect(foo_bar.all_following(public: true)).to be_empty
      expect(foo_bar.all_following(public: false)).to eq([other])
    end

    it "adds a non-public followers relationship" do
      other.follow(foo_bar).save
      expect(foo_bar.all_followers(public: true)).to be_empty
      expect(foo_bar.all_followers(public: false)).to eq([other])
    end
  end

  describe "#follows?" do
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    before_each { foo_bar.follow(other, confirmed: true, visible: true).save }

    it "filters response based on confirmed state" do
      expect(foo_bar.follows?(other, confirmed: true)).to be_truthy
      expect(foo_bar.follows?(other, confirmed: false)).to be_falsey
    end

    it "filters response based on visible state" do
      expect(foo_bar.follows?(other, visible: true)).to be_truthy
      expect(foo_bar.follows?(other, visible: false)).to be_falsey
    end
  end

  context "for outbox" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro add_to_outbox(index)
      let(note{{index}}) do
        ActivityPub::Object::Note.new(
          iri: "https://test.test/objects/#{random_string}"
        )
      end
      let(activity{{index}}) do
        ActivityPub::Activity::Create.new(
          iri: "https://test.test/activities/#{random_string}",
          actor: subject,
          object: note{{index}},
          visible: false
        )
      end
      let!(relationship{{index}}) do
        Relationship::Content::Outbox.new(
          owner: subject,
          activity: activity{{index}},
          confirmed: true,
          created_at: Time.utc(2016, 2, 15, 10, 20, {{index}})
        ).save
      end
    end

    add_to_outbox(1)
    add_to_outbox(2)
    add_to_outbox(3)
    add_to_outbox(4)
    add_to_outbox(5)

    let(note) do
      ActivityPub::Object::Note.new(
        iri: "https://test.test/note"
      )
    end
    let(undo) do
      ActivityPub::Activity::Undo.new(
        iri: "https://test.test/undo",
        actor: subject,
        object: activity5
      )
    end
    let(announce) do
      ActivityPub::Activity::Announce.new(
        iri: "https://test.test/announce",
        actor: other,
        object: note5
      )
    end
    let(like) do
      ActivityPub::Activity::Like.new(
        iri: "https://test.test/like",
        actor: other,
        object: note4
      )
    end

    describe "#in_outbox" do
      it "instantiates the correct subclass" do
        expect(subject.in_outbox(1, 2, public: false).first).to be_a(ActivityPub::Activity::Create)
      end

      it "filters out non-public posts" do
        expect(subject.in_outbox(1, 2, public: true)).to be_empty
      end

      it "filters out deleted posts" do
        note5.delete
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out undone activities" do
        undo.save
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "includes count of announcements" do
        announce.save
        expect(subject.in_outbox(1, 2, public: false).map(&.as(ActivityPub::Activity::Create).object.announces)).to eq([1, 0])
      end

      it "includes count of likes" do
        like.save
        expect(subject.in_outbox(1, 2, public: false).map(&.as(ActivityPub::Activity::Create).object.likes)).to eq([0, 1])
      end

      it "paginates the results" do
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity5, activity4])
        expect(subject.in_outbox(2, 2, public: false)).to eq([activity3, activity2])
        expect(subject.in_outbox(2, 2, public: false).more?).to be_true
      end
    end

    describe "#in_outbox?" do
      it "returns true if object is in outbox" do
        expect(subject.in_outbox?(note1)).to be_truthy
      end

      it "returns false if object has been deleted" do
        note1.delete
        expect(subject.in_outbox?(note1)).to be_falsey
      end

      it "returns false if activity has been undone" do
        undo.save
        expect(subject.in_outbox?(note5)).to be_falsey
      end

      it "returns false if object is not in outbox" do
        expect(subject.in_outbox?(note)).to be_falsey
      end
    end
  end

  context "for inbox" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro add_to_inbox(index)
      let(note{{index}}) do
        ActivityPub::Object::Note.new(
          iri: "https://test.test/objects/#{random_string}"
        )
      end
      let(activity{{index}}) do
        ActivityPub::Activity::Create.new(
          iri: "https://test.test/activities/#{random_string}",
          actor: subject,
          object: note{{index}},
          visible: false
        )
      end
      let!(relationship{{index}}) do
        Relationship::Content::Inbox.new(
          owner: subject,
          activity: activity{{index}},
          confirmed: true,
          created_at: Time.utc(2016, 2, 15, 10, 20, {{index}})
        ).save
      end
    end

    add_to_inbox(1)
    add_to_inbox(2)
    add_to_inbox(3)
    add_to_inbox(4)
    add_to_inbox(5)

    let(note) do
      ActivityPub::Object::Note.new(
        iri: "https://test.test/note"
      )
    end
    let(undo) do
      ActivityPub::Activity::Undo.new(
        iri: "https://test.test/undo",
        actor: subject,
        object: activity5
      )
    end
    let(announce) do
      ActivityPub::Activity::Announce.new(
        iri: "https://test.test/announce",
        actor: other,
        object: note5
      )
    end
    let(like) do
      ActivityPub::Activity::Like.new(
        iri: "https://test.test/like",
        actor: other,
        object: note4
      )
    end

    describe "#in_inbox" do
      it "instantiates the correct subclass" do
        expect(subject.in_inbox(1, 2, public: false).first).to be_a(ActivityPub::Activity::Create)
      end

      it "filters out non-public posts" do
        expect(subject.in_inbox(1, 2, public: true)).to be_empty
      end

      it "filters out deleted posts" do
        note5.delete
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out undone activities" do
        undo.save
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "includes count of announcements" do
        announce.save
        expect(subject.in_inbox(1, 2, public: false).map(&.as(ActivityPub::Activity::Create).object.announces)).to eq([1, 0])
      end

      it "includes count of likes" do
        like.save
        expect(subject.in_inbox(1, 2, public: false).map(&.as(ActivityPub::Activity::Create).object.likes)).to eq([0, 1])
      end

      it "paginates the results" do
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity5, activity4])
        expect(subject.in_inbox(2, 2, public: false)).to eq([activity3, activity2])
        expect(subject.in_inbox(2, 2, public: false).more?).to be_true
      end
    end

    describe "#in_inbox?" do
      it "returns true if object is in inbox" do
        expect(subject.in_inbox?(note1)).to be_truthy
      end

      it "returns false if object has been deleted" do
        note1.delete
        expect(subject.in_inbox?(note1)).to be_falsey
      end

      it "returns false if activity has been undone" do
        undo.save
        expect(subject.in_inbox?(note5)).to be_falsey
      end

      it "returns false if object is not in inbox" do
        expect(subject.in_inbox?(note)).to be_falsey
      end
    end
  end

  describe "#both_mailboxes" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro add_to_mailbox(index, box)
      let(activity{{index}}) do
        ActivityPub::Activity::Create.new(
          iri: "https://test.test/activities/#{random_string}",
          actor: subject,
          published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
          visible: false
        )
      end
      let!(relationship{{index}}) do
        Relationship::Content::{{box}}.new(
          owner: subject,
          activity: activity{{index}},
          confirmed: true
        ).save
      end
    end

    add_to_mailbox(1, Inbox)
    add_to_mailbox(2, Outbox)
    add_to_mailbox(3, Inbox)
    add_to_mailbox(4, Outbox)
    add_to_mailbox(5, Inbox)

    let(note) do
      ActivityPub::Object::Note.new(
        iri: "https://test.test/note"
      )
    end

    let(undo) do
      ActivityPub::Activity::Undo.new(
        iri: "https://test.test/undo",
        actor: subject,
        object: activity5
      )
    end

    it "instantiates the correct subclass" do
      expect(subject.both_mailboxes(1, 2).first).to be_a(ActivityPub::Activity::Create)
    end

    it "filters out deleted posts" do
      activity5.assign(object: note).save ; note.delete
      expect(subject.both_mailboxes(1, 2)).to eq([activity4, activity3])
    end

    it "filters out undone activities" do
      undo.save
      expect(subject.both_mailboxes(1, 2)).to eq([activity4, activity3])
    end

    it "paginates the results" do
      expect(subject.both_mailboxes(1, 2)).to eq([activity5, activity4])
      expect(subject.both_mailboxes(2, 2)).to eq([activity3, activity2])
      expect(subject.both_mailboxes(2, 2).more?).to be_true
    end
  end

  describe "#public_posts" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro post(index)
      let!(activity{{index}}) do
        ActivityPub::Activity::Create.new(
          iri: "https://test.test/activities/#{random_string}",
          actor: subject,
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

    let(note) do
      ActivityPub::Object::Note.new(
        iri: "https://test.test/note"
      )
    end

    let(undo) do
      ActivityPub::Activity::Undo.new(
        iri: "https://test.test/undo",
        actor: subject,
        object: activity5
      )
    end

    it "instantiates the correct subclass" do
      expect(subject.public_posts(1, 2).first).to be_a(ActivityPub::Activity::Create)
    end

    it "filters out non-public posts" do
      expect(subject.public_posts(1, 2)).to eq([activity5, activity3])
    end

    it "filters out deleted posts" do
      activity5.assign(object: note).save ; note.delete
      expect(subject.public_posts(1, 2)).to eq([activity3, activity1])
    end

    it "filters out undone activities" do
      undo.save
      expect(subject.public_posts(1, 2)).to eq([activity3, activity1])
    end

    it "paginates the results" do
      expect(subject.public_posts(1, 2)).to eq([activity5, activity3])
      expect(subject.public_posts(2, 2)).to eq([activity1])
      expect(subject.public_posts(2, 2).more?).not_to be_true
    end
  end

  describe "#account_uri" do
    it "returns the webfinger account uri" do
      expect(described_class.new(iri: "https://test.test/actors/foo_bar", username: "foobar").account_uri).to eq("foobar@test.test")
      expect(described_class.new(iri: "https://remote/foo_bar", username: "foobar").account_uri).to eq("foobar@remote")
    end
  end
end
