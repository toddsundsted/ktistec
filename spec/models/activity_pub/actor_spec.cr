require "../../../src/models/activity_pub/actor"
require "../../../src/models/activity_pub/object/note"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class FooBarActor < ActivityPub::Actor
end

Spectator.describe ActivityPub::Actor do
  setup_spec

  let(username) { random_string }
  let(password) { random_string }

  describe "#username=" do
    subject { described_class.new(iri: "https://test.test/actors/#{random_string}") }

    it "assigns iri" do
      expect{subject.assign(username: "foobar").save}.to change{subject.iri}
    end

    it "assigns inbox" do
      expect{subject.assign(username: "foobar").save}.to change{subject.inbox}
    end

    it "assigns outbox" do
      expect{subject.assign(username: "foobar").save}.to change{subject.outbox}
    end

    it "assigns following" do
      expect{subject.assign(username: "foobar").save}.to change{subject.following}
    end

    it "assigns followers" do
      expect{subject.assign(username: "foobar").save}.to change{subject.followers}
    end

    it "assigns urls" do
      expect{subject.assign(username: "foobar").save}.to change{subject.urls}
    end

    it "assigns attachments" do
      expect{subject.assign(username: "foobar").save}.to change{subject.attachments}
    end

    it "doesn't assign if the actor isn't local" do
      expect{subject.assign(iri: "https://remote/object", username: "foobar").save}.not_to change{subject.urls}
    end
  end

  describe ".match?" do
    let!(actor) do
      described_class.new(
        iri: "https://bar.com/actor",
        username: "foo",
        urls: ["https://bar.com/@foo"],
        attachments: [] of ActivityPub::Actor::Attachment
      ).save
    end

    it "returns the matched actor" do
      expect(described_class.match?("foo@bar.com")).to eq(actor)
    end

    it "returns nil on failed match" do
      expect(described_class.match?("")).to be_nil
    end

    context "given empty urls" do
      before_each { actor.assign(iri: "https://bar.com/actors/foo", urls: [] of String).save }

      it "matches on the iri" do
        expect(described_class.match?("foo@bar.com")).to eq(actor)
      end
    end

    context "given nil urls" do
      before_each { actor.assign(iri: "https://bar.com/actors/foo", urls: nil).save }

      it "matches on the iri" do
        expect(described_class.match?("foo@bar.com")).to eq(actor)
      end
    end
  end

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
          "https://w3id.org/security/v1",
          {
            "schema":"http://schema.org#",
            "PropertyValue":"schema:PropertyValue",
            "value":"schema:value"
          }
        ],
        "@id":"https://remote/foo_bar",
        "@type":"FooBarActor",
        "preferredUsername":"foo_bar",
        "publicKey":{
          "id":"https://remote/foo_bar#public-key",
          "owner":"https://remote/foo_bar",
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
        "url":"url link",
        "attachment": [
          {"name": "Blog", "type": "PropertyValue", "value": "https://somewhere.example.com"},
          {"name": "Website", "type": "PropertyValue", "value": "http://site.example.com"},
          {"name": "", "type": "invalid entry", "value": "http://site.example.com"}
        ]
      }
    JSON
  end

  describe ".map" do
    let(json) { super.gsub(/"icon": {[^}]+}/, icon) }

    context "given an array of icons with width and height" do
      let(icon) do
        <<-ICON
          "icon": [{
            "type": "Image",
            "mediaType": "image/jpeg",
            "height": 40, "width": 40,
            "url": "first link"
          }, {
            "type": "Image",
            "mediaType": "image/jpeg",
            "height": 120, "width": 120,
            "url": "second link"
          }]
        ICON
      end

      it "picks the largest icon" do
        expect(described_class.map(json)["icon"]).to eq("second link")
      end
    end

    context "given an array of icons" do
      let(icon) do
        <<-ICON
          "icon": [{
            "type": "Image",
            "mediaType": "image/jpeg",
            "url": "first link"
          }, {
            "type": "Image",
            "mediaType": "image/jpeg",
            "url": "second link"
          }]
        ICON
      end

      it "picks the first icon" do
        expect(described_class.map(json)["icon"]).to eq("first link")
      end
    end
  end

  describe ".from_json_ld" do
    it "instantiates the subclass" do
      actor = described_class.from_json_ld(json)
      expect(actor.class).to eq(FooBarActor)
    end

    it "creates a new instance" do
      actor = described_class.from_json_ld(json).save
      expect(actor.iri).to eq("https://remote/foo_bar")
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

      expect(actor.attachments).not_to be_nil
      attachments = actor.attachments.not_nil!
      expect(attachments.size).to eq(2)
      expect(attachments.all? { |a| a.type == "http://schema.org#PropertyValue" }).to be_true
      expect(attachments.first.name).to eq("Blog")
      expect(attachments.first.value).to eq("https://somewhere.example.com")
      expect(attachments.last.name).to eq("Website")
      expect(attachments.last.value).to eq("http://site.example.com")
    end

    it "includes the public key" do
      actor = described_class.from_json_ld(json, include_key: true).save
      expect(actor.pem_public_key).to eq("---PEM PUBLIC KEY---")
    end

    context "given an array of URLs" do
      let(json) { super.gsub(/"url":"url link"/, %q|"url":["url one","url two"]|) }

      it "parses the array of URLs" do
        actor = described_class.from_json_ld(json)
        expect(actor.urls).to eq(["url one", "url two"])
      end
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      actor = described_class.new.from_json_ld(json).save
      expect(actor.iri).to eq("https://remote/foo_bar")
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

      expect(actor.attachments).not_to be_nil
      attachments = actor.attachments.not_nil!
      expect(attachments.size).to eq(2)
      expect(attachments.all? { |a| a.type == "http://schema.org#PropertyValue" }).to be_true
      expect(attachments.first.name).to eq("Blog")
      expect(attachments.first.value).to eq("https://somewhere.example.com")
      expect(attachments.last.name).to eq("Website")
      expect(attachments.last.value).to eq("http://site.example.com")
    end

    it "includes the public key" do
      actor = described_class.new.from_json_ld(json, include_key: true).save
      expect(actor.pem_public_key).to eq("---PEM PUBLIC KEY---")
    end

    context "given an array of URLs" do
      let(json) { super.gsub(/"url":"url link"/, %q|"url":["url one","url two"]|) }

      it "parses the array of URLs" do
        actor = described_class.new.from_json_ld(json)
        expect(actor.urls).to eq(["url one", "url two"])
      end
    end
  end

  describe "#to_json_ld" do
    let(actor) { described_class.from_json_ld(json) }

    it "renders an identical instance" do
      # attachment values may change round trip because of the
      # Mastodon compatibile post-processing that happens to URLs,
      # so clear the attachments for this test.
      actor.attachments.try(&.clear)
      expect(described_class.from_json_ld(actor.to_json_ld)).to eq(actor)
    end

    it "renders the URL" do
      expect(actor.to_json_ld).to match(/"url":"url link"/)
    end

    context "given an array of URLs" do
      before_each { actor.assign(urls: ["url one", "url two"]) }

      it "renders the array of URLs" do
        expect(actor.to_json_ld).to match(/"url":\["url one","url two"\]/)
      end
    end

    context "given an array of attachments" do
      it "renders the array of attachments, with html links" do
        expect(actor.to_json_ld).to match(/"attachment":\[[^\]]+\]/)
        expect(actor.to_json_ld).to match(%r{"value\":\"<a href=\\\"https://somewhere.example.com\\\" target=\\\"_blank\\\" rel=\\\"nofollow noopener noreferrer me\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"\\\">somewhere.example.com</span><span class=\\\"invisible\\\"></span></a>\"})
      end
    end
  end

  describe "#make_delete_activity" do
    subject do
      described_class.new(
        iri: "https://test.test/actors/actor",
        followers: "followers",
        following: "following"
      )
    end

    it "instantiates a delete activity for the subject" do
      expect(subject.make_delete_activity).to be_a(ActivityPub::Activity::Delete)
    end

    it "assigns the subject as the actor" do
      expect(subject.make_delete_activity.actor).to eq(subject)
    end

    it "assigns the subject as the object" do
      expect(subject.make_delete_activity.object).to eq(subject)
    end

    it "addresses (to) the public collection" do
      expect(subject.make_delete_activity.to).to eq(["https://www.w3.org/ns/activitystreams#Public"])
    end

    it "addresses (cc) the subject's followers and following" do
      expect(subject.make_delete_activity.cc).to contain_exactly("followers", "following")
    end
  end

  describe "#down?" do
    let_build(:actor)

    before_each { actor.up! }

    it "indicates that the actor is down" do
      expect(actor.assign(down_at: Time.utc).down?).to be_true
    end

    it "indicates that the actor is not down" do
      expect(actor.assign(down_at: nil).down?).to be_false
    end
  end

  describe "#up?" do
    let_build(:actor)

    before_each { actor.down! }

    it "indicates that the actor is not up" do
      expect(actor.assign(down_at: Time.utc).up?).to be_false
    end

    it "indicates that the actor is up" do
      expect(actor.assign(down_at: nil).up?).to be_true
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

    it "does not display a deleted following actor" do
      foo_bar.follow(other, confirmed: true, visible: true).save
      other.delete!
      expect(foo_bar.all_following(public: true)).to be_empty
      expect(foo_bar.all_following(public: false)).to be_empty
    end

    it "does not display a blocked following actor" do
      foo_bar.follow(other, confirmed: true, visible: true).save
      other.block!
      expect(foo_bar.all_following(public: true)).to be_empty
      expect(foo_bar.all_following(public: false)).to be_empty
    end

    it "does not display a deleted followers actor" do
      other.follow(foo_bar, confirmed: true, visible: true).save
      other.delete!
      expect(foo_bar.all_followers(public: true)).to be_empty
      expect(foo_bar.all_followers(public: false)).to be_empty
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

    it "returns falsey for deleted actors" do
      other.delete!
      expect(foo_bar.follows?(other)).to be_falsey
    end

    it "returns falsey for blocked actors" do
      other.block!
      expect(foo_bar.follows?(other)).to be_falsey
    end
  end

  describe "#drafts" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro create_draft(index)
      let_create!(:note, named: note{{index}}, attributed_to: subject)
    end

    create_draft(1)
    create_draft(2)
    create_draft(3)
    create_draft(4)
    create_draft(5)

    it "instantiates the correct subclass" do
      expect(subject.drafts(1, 2).first).to be_a(ActivityPub::Object::Note)
    end

    it "filters out deleted posts" do
      note5.delete!
      expect(subject.drafts(1, 2)).to eq([note4, note3])
    end

    it "filters out blocked posts" do
      note5.block!
      expect(subject.drafts(1, 2)).to eq([note4, note3])
    end

    it "filters out published posts" do
      note5.assign(published: Time.utc).save
      expect(subject.drafts(1, 2)).to eq([note4, note3])
    end

    it "includes only posts attributed to subject" do
      note5.assign(attributed_to: other).save
      expect(subject.drafts(1, 2)).to eq([note4, note3])
    end

    it "paginates the results" do
      expect(subject.drafts(1, 2)).to eq([note5, note4])
      expect(subject.drafts(2, 2)).to eq([note3, note2])
      expect(subject.drafts(2, 2).more?).to be_true
    end
  end

  context "for outbox" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }
    let(deleted) { described_class.new(iri: "https://test.test/#{random_string}").save.delete! }
    let(blocked) { described_class.new(iri: "https://test.test/#{random_string}").save.block! }
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro add_to_outbox(index)
      let_build(:note, named: note{{index}})
      let_build(
        :create, named: activity{{index}},
        actor: subject,
        object: note{{index}},
        visible: false
      )
      let_create!(
        :outbox_relationship, named: nil,
        owner: subject,
        activity: activity{{index}},
        confirmed: true
      )
    end

    add_to_outbox(1)
    add_to_outbox(2)
    add_to_outbox(3)
    add_to_outbox(4)
    add_to_outbox(5)

    describe "#in_outbox" do
      it "instantiates the correct subclass" do
        expect(subject.in_outbox(1, 2, public: false).first).to be_a(ActivityPub::Activity::Create)
      end

      it "filters out non-public posts" do
        expect(subject.in_outbox(1, 2, public: true)).to be_empty
      end

      it "filters out deleted posts" do
        note5.delete!
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out blocked posts" do
        note5.block!
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out posts by deleted actors" do
        activity5.assign(actor: deleted).save
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out posts by blocked actors" do
        activity5.assign(actor: blocked).save
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out undone activities" do
        activity5.undo!
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "includes replies" do
        note5.assign(in_reply_to: note4).save
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity5, activity4])
      end

      it "paginates the results" do
        expect(subject.in_outbox(1, 2, public: false)).to eq([activity5, activity4])
        expect(subject.in_outbox(2, 2, public: false)).to eq([activity3, activity2])
        expect(subject.in_outbox(2, 2, public: false).more?).to be_true
      end
    end

    let_build(:note)

    describe "#in_outbox?" do
      it "returns true if object is in outbox" do
        expect(subject.in_outbox?(note1)).to be_truthy
      end

      it "returns false if object has been deleted" do
        note1.delete!
        expect(subject.in_outbox?(note1)).to be_falsey
      end

      it "returns false if object has been blocked" do
        note1.block!
        expect(subject.in_outbox?(note1)).to be_falsey
      end

      it "returns false if actor of activity has been deleted" do
        activity5.assign(actor: deleted).save
        expect(subject.in_outbox?(note5)).to be_falsey
      end

      it "returns false if actor of activity has been blocked" do
        activity5.assign(actor: blocked).save
        expect(subject.in_outbox?(note5)).to be_falsey
      end

      it "returns false if activity has been undone" do
        activity5.undo!
        expect(subject.in_outbox?(note5)).to be_falsey
      end

      it "returns false if object is not in outbox" do
        expect(subject.in_outbox?(note)).to be_falsey
      end
    end
  end

  context "for inbox" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }
    let(deleted) { described_class.new(iri: "https://test.test/#{random_string}").save.delete! }
    let(blocked) { described_class.new(iri: "https://test.test/#{random_string}").save.block! }
    let(other) { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro add_to_inbox(index)
      let_build(:note, named: note{{index}})
      let_build(
        :create, named: activity{{index}},
        actor: subject,
        object: note{{index}},
        visible: false
      )
      let_create!(
        :inbox_relationship, named: nil,
        owner: subject,
        activity: activity{{index}},
        confirmed: true
      )
    end

    add_to_inbox(1)
    add_to_inbox(2)
    add_to_inbox(3)
    add_to_inbox(4)
    add_to_inbox(5)

    describe "#in_inbox" do
      it "instantiates the correct subclass" do
        expect(subject.in_inbox(1, 2, public: false).first).to be_a(ActivityPub::Activity::Create)
      end

      it "filters out non-public posts" do
        expect(subject.in_inbox(1, 2, public: true)).to be_empty
      end

      it "filters out deleted posts" do
        note5.delete!
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out blocked posts" do
        note5.block!
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out posts by deleted actors" do
        activity5.assign(actor: deleted).save
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out posts by blocked actors" do
        activity5.assign(actor: blocked).save
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "filters out undone activities" do
        activity5.undo!
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity4, activity3])
      end

      it "includes replies" do
        note5.assign(in_reply_to: note4).save
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity5, activity4])
      end

      it "paginates the results" do
        expect(subject.in_inbox(1, 2, public: false)).to eq([activity5, activity4])
        expect(subject.in_inbox(2, 2, public: false)).to eq([activity3, activity2])
        expect(subject.in_inbox(2, 2, public: false).more?).to be_true
      end
    end

    let_build(:note)

    describe "#in_inbox?" do
      it "returns true if object is in inbox" do
        expect(subject.in_inbox?(note1)).to be_truthy
      end

      it "returns false if object has been deleted" do
        note1.delete!
        expect(subject.in_inbox?(note1)).to be_falsey
      end

      it "returns false if object has been blocked" do
        note1.block!
        expect(subject.in_inbox?(note1)).to be_falsey
      end

      it "returns false if actor of activity has been deleted" do
        activity5.assign(actor: deleted).save
        expect(subject.in_inbox?(note5)).to be_falsey
      end

      it "returns false if actor of activity has been blocked" do
        activity5.assign(actor: blocked).save
        expect(subject.in_inbox?(note5)).to be_falsey
      end

      it "returns false if activity has been undone" do
        activity5.undo!
        expect(subject.in_inbox?(note5)).to be_falsey
      end

      it "returns false if object is not in inbox" do
        expect(subject.in_inbox?(note)).to be_falsey
      end
    end
  end

  describe "#find_activity_for" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro create_activity(index)
      let_build(:note, named: note{{index}})
      let_create!(:create, named: activity{{index}}, actor: subject, object: note{{index}})
    end

    create_activity(1)

    it "instantiates the correct subclass" do
      expect(subject.find_activity_for(note1)).to be_a(ActivityPub::Activity::Create)
    end

    it "filters out deleted posts" do
      note1.delete!
      expect(subject.find_activity_for(note1)).to be_nil
    end

    it "filters out blocked posts" do
      note1.block!
      expect(subject.find_activity_for(note1)).to be_nil
    end

    it "filters out posts by deleted actors" do
      subject.delete!
      expect(subject.find_activity_for(note1)).to be_nil
    end

    it "filters out posts by blocked actors" do
      subject.block!
      expect(subject.find_activity_for(note1)).to be_nil
    end

    it "filters out undone activities" do
      activity1.undo!
      expect(subject.find_activity_for(note1)).to be_nil
    end

    it "filters for specific activities" do
      expect(subject.find_activity_for(note1, inclusion: "ActivityPub::Activity::Delete")).to be_nil
    end

    it "filters out specific activities" do
      expect(subject.find_activity_for(note1, exclusion: "ActivityPub::Activity::Create")).to be_nil
    end

    it "returns the first activity" do
      activity1.dup.assign(id: nil, iri: "https://test.test/activities/#{random_string}").save
      expect(subject.find_activity_for(note1)).to eq(activity1)
    end
  end

  describe "#known_posts" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro post(index)
      let_create!(
        :object, named: post{{index}},
        attributed_to: subject,
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
      expect(subject.known_posts(1, 2).first).to be_a(ActivityPub::Object)
    end

    it "filters out non-public posts" do
      expect(subject.known_posts(1, 2)).to eq([post5, post3])
    end

    it "filters out deleted posts" do
      post5.delete!
      expect(subject.known_posts(1, 2)).to eq([post3, post1])
    end

    it "filters out blocked posts" do
      post5.block!
      expect(subject.known_posts(1, 2)).to eq([post3, post1])
    end

    it "paginates the results" do
      expect(subject.known_posts(1, 2)).to eq([post5, post3])
      expect(subject.known_posts(2, 2)).to eq([post1])
      expect(subject.known_posts(2, 2).more?).not_to be_true
    end
  end

  describe "#public_posts" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: object{{index}}, attributed_to: actor{{index}})
      let_build(:announce, named: activity{{index}}, actor: subject, object: object{{index}})
      let_create!(:outbox_relationship, named: nil, owner: subject, activity: activity{{index}})
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

    it "instantiates the correct subclass" do
      expect(subject.public_posts(1, 2).first).to be_a(ActivityPub::Object)
    end

    it "filters out deleted posts" do
      object5.delete!
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out blocked posts" do
      object5.block!
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out non-public posts" do
      object5.assign(visible: false).save
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out replies" do
      object5.assign(in_reply_to: object3).save
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out objects belonging to undone activities" do
      activity5.undo!
      expect(subject.public_posts(1, 2)).to eq([object4, object3])
    end

    let_build(:create, actor: subject, object: object5)
    let_build(:outbox_relationship, named: :outbox, owner: subject, activity: create)

    it "paginates the results" do
      expect(subject.public_posts(1, 2)).to eq([object5, object4])
      expect(subject.public_posts(3, 2)).to eq([object1])
      expect(subject.public_posts(3, 2).more?).not_to be_true
    end
  end

  describe "#all_posts" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: object{{index}}, attributed_to: actor{{index}})
      let_build(:announce, named: activity{{index}}, actor: subject, object: object{{index}})
      let_create!(:outbox_relationship, named: nil, owner: subject, activity: activity{{index}})
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

    it "instantiates the correct subclass" do
      expect(subject.all_posts(1, 2).first).to be_a(ActivityPub::Object)
    end

    it "filters out deleted posts" do
      object5.delete!
      expect(subject.all_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out blocked posts" do
      object5.block!
      expect(subject.all_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(subject.all_posts(1, 2)).to eq([object4, object3])
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(subject.all_posts(1, 2)).to eq([object4, object3])
    end

    it "includes non-public posts" do
      object5.assign(visible: false).save
      expect(subject.all_posts(1, 2)).to eq([object5, object4])
    end

    it "includes replies" do
      object5.assign(in_reply_to: object3).save
      expect(subject.all_posts(1, 2)).to eq([object5, object4])
    end

    it "filters out objects belonging to undone activities" do
      activity5.undo!
      expect(subject.all_posts(1, 2)).to eq([object4, object3])
    end

    let_build(:create, actor: subject, object: object5)
    let_build(:outbox_relationship, named: :outbox, owner: subject, activity: create)

    it "paginates the results" do
      expect(subject.all_posts(1, 2)).to eq([object5, object4])
      expect(subject.all_posts(3, 2)).to eq([object1])
      expect(subject.all_posts(3, 2).more?).not_to be_true
    end
  end

  describe "#timeline" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro post(index)
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: object{{index}}, attributed_to: actor{{index}})
      let_create!(:announce, named: activity{{index}}, actor: actor{{index}}, object: object{{index}})
      let_create!(:inbox_relationship, named: nil, owner: subject, activity: activity{{index}})
      let_create!(:timeline_announce, named: timeline{{index}}, owner: subject, object: object{{index}})
    end

    post(1)
    post(2)
    post(3)
    post(4)
    post(5)

    let(since) { KTISTEC_EPOCH }

    it "instantiates the correct subclass" do
      expect(subject.timeline(page: 1, size: 2).first).to be_a(Relationship::Content::Timeline)
    end

    it "returns the count" do
      expect(subject.timeline(since: since)).to eq(5)
    end

    it "filters out deleted posts" do
      object5.delete!
      expect(subject.timeline(page: 1, size: 2)).to eq([timeline4, timeline3])
      expect(subject.timeline(since: since)).to eq(4)
    end

    it "filters out blocked posts" do
      object5.block!
      expect(subject.timeline(page: 1, size: 2)).to eq([timeline4, timeline3])
      expect(subject.timeline(since: since)).to eq(4)
    end

    it "filters out posts by deleted actors" do
      actor5.delete!
      expect(subject.timeline(page: 1, size: 2)).to eq([timeline4, timeline3])
      expect(subject.timeline(since: since)).to eq(4)
    end

    it "filters out posts by blocked actors" do
      actor5.block!
      expect(subject.timeline(page: 1, size: 2)).to eq([timeline4, timeline3])
      expect(subject.timeline(since: since)).to eq(4)
    end

    it "filters out posts not associated with included activities" do
      expect(subject.timeline(inclusion: [Relationship::Content::Timeline::Announce], page: 1, size: 2)).to eq([timeline5, timeline4])
      expect(subject.timeline(since: since, inclusion: [Relationship::Content::Timeline::Announce])).to eq(5)
    end

    it "filters out posts not associated with included activities" do
      expect(subject.timeline(inclusion: [Relationship::Content::Timeline::Create], page: 1, size: 2)).to be_empty
      expect(subject.timeline(since: since, inclusion: [Relationship::Content::Timeline::Create])).to eq(0)
    end

    context "given a prior create not in timeline" do
      let_create!(:create, actor: actor5, object: object5)

      it "includes announcements by default" do
        expect(subject.timeline(page: 1, size: 2)).to eq([timeline5, timeline4])
        expect(subject.timeline(since: since)).to eq(5)
      end

      it "includes announcements" do
        expect(subject.timeline(inclusion: [Relationship::Content::Timeline::Announce], page: 1, size: 2)).to eq([timeline5, timeline4])
        expect(subject.timeline(since: since, inclusion: [Relationship::Content::Timeline::Announce])).to eq(5)
      end

      it "filters out announcements" do
        expect(subject.timeline(inclusion: [Relationship::Content::Timeline::Create], page: 1, size: 2)).to be_empty
        expect(subject.timeline(since: since, inclusion: [Relationship::Content::Timeline::Create])).to eq(0)
      end
    end

    context "given a reply" do
      before_each { object4.assign(in_reply_to: object5).save }

      it "includes replies by default" do
        expect(subject.timeline(page: 1, size: 2)).to eq([timeline5, timeline4])
        expect(subject.timeline(since: since)).to eq(5)
      end

      it "includes replies" do
        expect(subject.timeline(exclude_replies: false, page: 1, size: 2)).to eq([timeline5, timeline4])
        expect(subject.timeline(since: since, exclude_replies: false)).to eq(5)
      end

      it "filters out replies" do
        expect(subject.timeline(exclude_replies: true, page: 1, size: 2)).to eq([timeline5, timeline3])
        expect(subject.timeline(since: since, exclude_replies: true)).to eq(4)
      end
    end

    context "given a local post" do
      let_build(:object, attributed_to: subject)
      let_create!(:create, actor: subject, object: object)
      let_create!(:outbox_relationship, owner: subject, activity: create)
      let_create!(:timeline, owner: subject, object: object)

      it "includes the post" do
        expect(subject.timeline(page: 1, size: 2)).to eq([timeline, timeline5])
        expect(subject.timeline(since: since)).to eq(6)
      end
    end

    context "given a post without an associated activity" do
      let_build(:object, attributed_to: subject)
      let_create!(:timeline, owner: subject, object: object)

      it "includes the post" do
        expect(subject.timeline(page: 1, size: 2)).to eq([timeline, timeline5])
        expect(subject.timeline(since: since)).to eq(6)
      end
    end

    it "paginates the results" do
      expect(subject.timeline(page: 1, size: 2)).to eq([timeline5, timeline4])
      expect(subject.timeline(page: 3, size: 2)).to eq([timeline1])
      expect(subject.timeline(page: 3, size: 2).more?).not_to be_true
    end
  end

  describe "#notifications" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    macro notification(index)
      let_build(:actor, named: actor{{index}})
      let_build(:object, named: object{{index}})
      let_build(:announce, named: activity{{index}}, actor: actor{{index}}, object: object{{index}})
      let_create!(:notification_announce, named: notification{{index}}, owner: subject, activity: activity{{index}})
    end

    notification(1)
    notification(2)
    notification(3)
    notification(4)
    notification(5)

    let(since) { KTISTEC_EPOCH }

    it "instantiates the correct subclass" do
      expect(subject.notifications(page: 1, size: 2).first).to be_a(Relationship::Content::Notification)
    end

    it "returns the count" do
      expect(subject.notifications(since: since)).to eq(5)
    end

    it "filters out undone activities" do
      activity5.undo!
      expect(subject.notifications(page: 1, size: 2)).to eq([notification4, notification3])
      expect(subject.notifications(since: since)).to eq(4)
    end

    it "filters out activities with deleted objects" do
      object5.delete!
      expect(subject.notifications(page: 1, size: 2)).to eq([notification4, notification3])
      expect(subject.notifications(since: since)).to eq(4)
    end

    it "filters out activities with blocked objects" do
      object5.block!
      expect(subject.notifications(page: 1, size: 2)).to eq([notification4, notification3])
      expect(subject.notifications(since: since)).to eq(4)
    end

    it "filters out activities from deleted actors" do
      actor5.delete!
      expect(subject.notifications(page: 1, size: 2)).to eq([notification4, notification3])
      expect(subject.notifications(since: since)).to eq(4)
    end

    it "filters out activities from blocked actors" do
      actor5.block!
      expect(subject.notifications(page: 1, size: 2)).to eq([notification4, notification3])
      expect(subject.notifications(since: since)).to eq(4)
    end

    it "paginates the results" do
      expect(subject.notifications(page: 1, size: 2)).to eq([notification5, notification4])
      expect(subject.notifications(page: 3, size: 2)).to eq([notification1])
      expect(subject.notifications(page: 3, size: 2).more?).not_to be_true
    end
  end

  context "approvals" do
    subject! do
      described_class.new(
        iri: "https://test.test/actors/actor"
      ).save
    end

    let_create!(:object)

    describe "#approve" do
      it "approves the object" do
        expect{subject.approve(object)}.to change{object.approved_by?(subject)}
      end
    end

    describe "#unapprove" do
      before_each { subject.approve(object) }

      it "unapproves the object" do
        expect{subject.unapprove(object)}.to change{object.approved_by?(subject)}
      end
    end
  end

  context "terms" do
    subject { described_class.new(iri: "https://test.test/#{random_string}").save }

    let_create!(:filter_term, named: term1, actor: subject, term: "one")
    let_create!(:filter_term, named: term2, actor: subject, term: "two")
    let_create!(:filter_term, named: term3, actor: subject, term: "three")
    let_create!(:filter_term, named: term4, actor: subject, term: "four")
    let_create!(:filter_term, named: term5, actor: subject, term: "five")
    let_create!(:filter_term, term: "term")

    pre_condition { expect(FilterTerm.count).to eq(6) }

    describe "#terms" do
      it "instantiates the correct subclass" do
        expect(subject.terms(page: 1, size: 2).first).to be_a(FilterTerm)
      end

      it "paginates the results" do
        expect(subject.terms(page: 1, size: 2)).to eq([term1, term2])
        expect(subject.terms(page: 3, size: 2)).to eq([term5])
        expect(subject.terms(page: 3, size: 2).more?).not_to be_true
      end
    end
  end

  describe "#handle" do
    it "returns the handle" do
      expect(described_class.new(iri: "https://test.test/actors/foo_bar", username: "foobar").handle).to eq("foobar@test.test")
      expect(described_class.new(iri: "https://remote/foo_bar", username: "foobar").handle).to eq("foobar@remote")
    end
  end
end
