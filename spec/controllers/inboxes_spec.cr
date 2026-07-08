require "../../src/models/activity_pub/object/note"
require "../../src/models/activity_pub/object/tombstone"
require "../../src/controllers/inboxes"

require "../spec_helper/controller"
require "../spec_helper/factory"
require "../spec_helper/network"

Spectator.describe InboxesController do
  setup_spec

  after_each do
    Ktistec::Server.clear_shutdown!
  end

  PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

  describe "POST /actors/:username/inbox" do
    let!(actor) { register.actor }

    # actor with keys is cached
    let_create(:actor, named: :other, with_keys: true)

    # don't directly associate the activity with the actor, yet
    let_build(:activity, actor_iri: other.iri)

    let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

    it "returns 410 if account is gone" do
      post "/actors/0/inbox", headers
      expect(response.status_code).to eq(410)
    end

    it "returns 503 if the server is shutting down" do
      Ktistec::Server.shutting_down = true
      post "/actors/#{actor.username}/inbox", headers, ""
      expect(response.status_code).to eq(503)
    end

    it "returns 400 if activity is blank" do
      post "/actors/#{actor.username}/inbox", headers, ""
      expect(JSON.parse(response.body)["msg"]).to eq("body is blank")
      expect(response.status_code).to eq(400)
    end

    it "returns 413 when Content-Length exceeds the cap" do
      body = "a" * (InboxesController::MAX_INBOX_REQUEST_BYTES + 1)
      post "/actors/#{actor.username}/inbox", headers, body
      expect(JSON.parse(response.body)["msg"]).to eq("payload too large")
      expect(response.status_code).to eq(413)
    end

    it "returns 413 when the body size exceeds the cap" do
      body = IO::Memory.new("a" * (InboxesController::MAX_INBOX_REQUEST_BYTES + 1))
      post "/actors/#{actor.username}/inbox", headers, body
      expect(JSON.parse(response.body)["msg"]).to eq("payload too large")
      expect(response.status_code).to eq(413)
    end

    it "returns 400 if activity can't be verified" do
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(JSON.parse(response.body)["msg"]).to eq("can't be verified")
      expect(response.status_code).to eq(400)
    end

    context "when activity was already received" do
      let_create!(:create)

      it "returns 200" do
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(recursive: true)
        expect(response.status_code).to eq(200)
      end
    end

    it "returns 400 if the activity cannot be deserialized due to an unsupported type" do
      json = %q|{"type":"Activity","id":"https://remote/one","actor":{"type":"Activity","id":"https://remote/two"}}|
      post "/actors/#{actor.username}/inbox", headers, json
      expect(JSON.parse(response.body)["msg"]).to eq("unsupported type")
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if activity is not supported" do
      HTTP::Client.activities << activity
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(JSON.parse(response.body)["msg"]).to eq("activity not supported")
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if actor is not present" do
      activity.actor_iri = nil
      HTTP::Client.activities << activity
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(JSON.parse(response.body)["msg"]).to eq("actor not present")
      expect(response.status_code).to eq(400)
    end

    it "does not save the activity on failure" do
      expect { post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld }
        .not_to change { ActivityPub::Activity.count }
      expect(response.status_code).not_to eq(200)
    end

    context "when unsigned" do
      let_build(:note, attributed_to: other)
      let_build(:create, named: :activity, actor: other, object: note)

      before_each { HTTP::Client.activities << activity }

      let(json_ld) { activity.to_json_ld }

      it "retrieves the activity from the origin" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.requests).to have("GET #{activity.iri}")
      end

      it "does not retrieve the actor from the origin" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
      end

      it "saves the activity" do
        expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
          .to change { ActivityPub::Activity.count }.by(1)
      end

      it "is successful" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(response.status_code).to eq(200)
      end

      context "and the actor is not cached" do
        let_build(:actor, named: :other, with_keys: true)

        before_each { HTTP::Client.actors << other }

        it "retrieves the actor from the origin" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).to have("GET #{other.iri}")
        end

        it "saves the actor" do
          expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
            .to change { ActivityPub::Actor.count }.by(1)
        end

        it "saves the actor's public key" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(ActivityPub::Actor.find(other.iri).pem_public_key).not_to be_nil
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end

        context "and the actor is embedded in the activity" do
          let(json_ld) { activity.to_json_ld(recursive: true) }

          pre_condition { expect(JSON.parse(json_ld).dig("actor", "id")).to eq(other.iri) }

          it "retrieves the actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "saves the actor" do
            expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
              .to change { ActivityPub::Actor.count }.by(1)
          end

          it "saves the actor's public key" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(ActivityPub::Actor.find(other.iri).pem_public_key).not_to be_nil
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "and the actor is referenced by the activity" do
          let(json_ld) { activity.to_json_ld(recursive: false) }

          pre_condition { expect(JSON.parse(json_ld).dig("actor")).to eq(other.iri) }

          it "retrieves the actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "saves the actor" do
            expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
              .to change { ActivityPub::Actor.count }.by(1)
          end

          it "saves the actor's public key" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(ActivityPub::Actor.find(other.iri).pem_public_key).not_to be_nil
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end
      end
    end

    context "when signed" do
      let_build(:note, attributed_to: other)
      let_build(:create, named: :activity, actor: other, object: note)

      before_each { HTTP::Client.objects << note }

      let(json_ld) { activity.to_json_ld }

      let(headers) { Ktistec::Signature.sign(other, actor.inbox.not_nil!, json_ld, "application/json") }

      context "and an actor claims a verifiable handle" do
        # un-saved, so the inbox dereferences it (rather than using a
        # cached instance) and thus runs `verify_handle!`.
        let_build(:actor, named: :other, with_keys: true)

        let(claimed) { "#{other.username}@remote" }

        # `other` is remote, so our own serializer omits `webfinger`.
        before_each do
          doc = JSON.parse(other.to_json_ld).as_h
          doc["@context"] = JSON::Any.new(doc["@context"].as_a << JSON::Any.new("https://purl.archive.org/socialweb/webfinger"))
          doc["webfinger"] = JSON::Any.new(claimed)
          HTTP::Client.cache[other.iri] = doc.to_json
        end

        it "verifies and stores the handle" do
          expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
            .to change { ActivityPub::Actor.find?(other.iri).try(&.verified_handle) }
              .from(nil).to(claimed)
        end
      end

      it "does not retrieve the activity from the origin" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
      end

      it "does not retrieve the actor from the origin" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
      end

      it "saves the activity" do
        expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
          .to change { ActivityPub::Activity.count }.by(1)
      end

      it "is successful" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(response.status_code).to eq(200)
      end

      context "and the actor is not cached" do
        let_build(:actor, named: :other, with_keys: true)

        before_each { HTTP::Client.actors << other }

        it "retrieves the actor from the origin" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).to have("GET #{other.iri}")
        end

        it "saves the actor" do
          expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
            .to change { ActivityPub::Actor.count }.by(1)
        end

        it "saves the actor's public key" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(ActivityPub::Actor.find(other.iri).pem_public_key).not_to be_nil
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end

        context "and the actor is embedded in the activity" do
          let(json_ld) { activity.to_json_ld(recursive: true) }

          pre_condition { expect(JSON.parse(json_ld).dig("actor", "id")).to eq(other.iri) }

          it "retrieves the remote actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "saves the actor" do
            expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
              .to change { ActivityPub::Actor.count }.by(1)
          end

          it "saves the actor's public key" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(ActivityPub::Actor.find(other.iri).pem_public_key).not_to be_nil
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "and the actor is referenced by the activity" do
          let(json_ld) { activity.to_json_ld(recursive: false) }

          pre_condition { expect(JSON.parse(json_ld).dig("actor")).to eq(other.iri) }

          it "retrieves the remote actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "saves the actor" do
            expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
              .to change { ActivityPub::Actor.count }.by(1)
          end

          it "saves the actor's public key" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(ActivityPub::Actor.find(other.iri).pem_public_key).not_to be_nil
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end
      end

      context "and the actor is cached" do
        pre_condition { expect(other.new_record?).to be_false }

        before_each { HTTP::Client.actors << other }

        context "but doesn't have a public key" do
          before_each { other.dup.assign(pem_public_key: nil).save }

          it "retrieves the actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "updates the actor's public key" do
            expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
              .to change { ActivityPub::Actor.find(other.id).pem_public_key }
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "but the public key is wrong" do
          before_each { other.dup.assign(pem_public_key: "").save }

          before_each do
            # surgically remove only the note so that the object
            # fetching fallback in the controller doesn't succeed
            HTTP::Client.objects.delete(note.iri)
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "does not retrieve the actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
          end

          it "returns 400 if the activity can't be verified" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(400)
          end
        end
      end

      context "and the actor is impersonated" do
        let_create(:actor, named: :impersonator, with_keys: true)

        let(headers) { Ktistec::Signature.sign(impersonator, actor.inbox.not_nil!, json_ld, "application/json") }

        before_each { HTTP::Client.activities << activity }

        it "retrieves the activity from the origin" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).to have("GET #{activity.iri}")
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end
      end

      context "and the signature header is malformed" do
        before_each { HTTP::Client.activities << activity }

        let(headers) do
          HTTP::Headers{
            "Content-Type" => "application/json",
            "Signature"    => "bogus",
          }
        end

        it "retrieves the activity from the origin" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).to have("GET #{activity.iri}")
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end
      end

      context "given a GoToSocial-style path keyId" do
        let(key_id) { "#{other.iri}/main-key" }

        # GoToSocial returns an actor stub with nested `publicKey`
        # see: https://docs.gotosocial.org/en/v0.21.2/federation/http_signatures/#quirks
        let(key_document) do
          {
            "@context" => [
              "https://w3id.org/security/v1",
              "https://www.w3.org/ns/activitystreams",
            ],
            "id"        => other.iri,
            "type"      => "Person",
            "publicKey" => {
              "id"           => key_id,
              "owner"        => other.iri,
              "publicKeyPem" => other.pem_public_key,
            },
          }.to_json
        end

        let(headers) do
          Ktistec::Signature.sign(other, actor.inbox.not_nil!, json_ld, "application/json").tap do |hdrs|
            hdrs["Signature"] = hdrs["Signature"].gsub(/keyId="[^"]*"/, %Q<keyId="#{key_id}">)
          end
        end

        before_each do
          HTTP::Client.cache[key_id] = key_document
          HTTP::Client.activities << activity
        end

        it "retrieves the key document" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).to have("GET #{key_id}")
        end

        it "does not retrieve the activity from the origin" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end

        context "and the actor is impersonated" do
          let_create(:actor, named: :impersonated, with_keys: true)

          let(key_document) do
            {
              "@context"  => ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"],
              "id"        => impersonated.iri,
              "type"      => "Person",
              "publicKey" => {
                "id"           => key_id,
                "owner"        => impersonated.iri,
                "publicKeyPem" => impersonated.pem_public_key,
              },
            }.to_json
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "and the resolved key id does not match the keyId" do
          let(key_document) do
            {
              "@context"  => ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"],
              "id"        => other.iri,
              "type"      => "Person",
              "publicKey" => {
                "id"           => "#{other.iri}/wrong-key",
                "owner"        => other.iri,
                "publicKeyPem" => other.pem_public_key,
              },
            }.to_json
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "and the publicKey is missing" do
          let(key_document) do
            {
              "@context" => ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"],
              "id"       => other.iri,
              "type"     => "Person",
            }.to_json
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "and fetching the key document fails" do
          let(key_id) { "https://remote/returns-500/main-key" }

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end
      end

      context "given a path keyId" do
        let(key_id) { "#{other.iri}/main-key" }

        let(key_document) do
          {
            "@context"     => "https://w3id.org/security/v1",
            "id"           => key_id,
            "owner"        => other.iri,
            "publicKeyPem" => other.pem_public_key,
          }.to_json
        end

        let(headers) do
          Ktistec::Signature.sign(other, actor.inbox.not_nil!, json_ld, "application/json").tap do |hdrs|
            hdrs["Signature"] = hdrs["Signature"].gsub(/keyId="[^"]*"/, %Q<keyId="#{key_id}">)
          end
        end

        before_each do
          HTTP::Client.cache[key_id] = key_document
          HTTP::Client.activities << activity
        end

        it "retrieves the key document" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).to have("GET #{key_id}")
        end

        it "does not retrieve the activity from the origin" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end

        context "and the actor is impersonated" do
          let_create(:actor, named: :impersonated, with_keys: true)

          let(key_document) do
            {
              "@context"     => "https://w3id.org/security/v1",
              "id"           => key_id,
              "owner"        => impersonated.iri,
              "publicKeyPem" => impersonated.pem_public_key,
            }.to_json
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end

        context "and the resolved key id does not match the keyId" do
          let(key_document) do
            {
              "@context"     => "https://w3id.org/security/v1",
              "id"           => "#{other.iri}/wrong-key",
              "owner"        => other.iri,
              "publicKeyPem" => other.pem_public_key,
            }.to_json
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(response.status_code).to eq(200)
          end
        end
      end
    end

    context "when the other actor is down" do
      let_build(:activity, actor: other, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", activity.to_json_ld(true), "application/json") }

      before_each { other.down! }

      it "marks the actor as up" do
        expect { post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(true) }
          .to change { other.reload!.up? }.to(true)
      end
    end

    alias Notification = Relationship::Content::Notification
    alias Timeline = Relationship::Content::Timeline

    context "on announce" do
      let_build(:note, attributed_to: other)
      let_build(:announce, actor: other, object: nil, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", announce.to_json_ld(true), "application/json") }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        announce.object_iri = note.iri
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        announce.object = note
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches the attributed to actor" do
        announce.object = note
        note.attributed_to_iri = "https://remote/actors/123"
        post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET https://remote/actors/123")
      end

      it "saves the object" do
        announce.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
          .to change { ActivityPub::Object.count(iri: note.iri) }.by(1)
      end

      it "puts the activity in the actor's inbox" do
        announce.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
          .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
      end

      it "puts the activity in the actor's notifications" do
        announce.object = note.assign(attributed_to: actor)
        expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
          .to change { Notification.count(from_iri: actor.iri) }.by(1)
      end

      it "puts the object in the actor's timeline" do
        announce.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
          .to change { Timeline.count(from_iri: actor.iri) }.by(1)
      end

      context "and the object's already in the timeline" do
        let_create!(:timeline_announce, owner: actor, object: note)

        it "does not put the object in the actor's timeline" do
          announce.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
            .not_to change { Timeline.count(from_iri: actor.iri) }
        end
      end

      context "and the object's a reply" do
        let_build(:object, named: parent)

        before_each do
          note.assign(in_reply_to: parent).save
        end

        it "puts the object in the actor's timeline" do
          announce.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
            .to change { Timeline.count(from_iri: actor.iri) }.by(1)
        end
      end

      context "and the activity is addressed to the other's followers" do
        before_each do
          other.assign(followers: "#{other.iri}/followers").save
          announce.assign(to: ["#{other.iri}/followers"])
        end

        it "does not put the activity in the actor's inbox" do
          announce.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
            .not_to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other, confirmed: true).save
          end

          it "puts the activity in the actor's inbox" do
            announce.object = note
            expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
              .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
          end
        end
      end

      context "and the activity is addressed to the public collection" do
        before_each do
          announce.assign(to: [PUBLIC])
        end

        it "does not put the activity in the actor's inbox" do
          announce.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
            .not_to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other, confirmed: true).save
          end

          it "puts the activity in the actor's inbox" do
            announce.object = note
            expect { post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true) }
              .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
          end
        end
      end

      it "is successful" do
        announce.object = note
        post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)
        expect(response.status_code).to eq(200)
      end
    end

    context "on like" do
      let_build(:note, attributed_to: other)
      let_build(:like, actor: other, object: nil, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", like.to_json_ld(true), "application/json") }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        like.object_iri = note.iri
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        like.object = note
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches the attributed to actor" do
        like.object = note
        note.attributed_to_iri = "https://remote/actors/123"
        post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET https://remote/actors/123")
      end

      it "saves the object" do
        like.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true) }
          .to change { ActivityPub::Object.count(iri: note.iri) }.by(1)
      end

      it "puts the activity in the actor's inbox" do
        like.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true) }
          .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
      end

      it "puts the activity in the actor's notifications" do
        like.object = note.assign(attributed_to: actor)
        expect { post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true) }
          .to change { Notification.count(from_iri: actor.iri) }.by(1)
      end

      it "does not put the object in the actor's timeline" do
        like.object = note.assign(attributed_to: actor)
        expect { post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true) }
          .not_to change { Timeline.count(from_iri: actor.iri) }
      end
    end

    context "on dislike" do
      let_build(:note, attributed_to: other)
      let_build(:dislike, actor: other, object: nil, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", dislike.to_json_ld(true), "application/json") }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        dislike.object_iri = note.iri
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        dislike.object = note
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches the attributed to actor" do
        dislike.object = note
        note.attributed_to_iri = "https://remote/actors/123"
        post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET https://remote/actors/123")
      end

      it "saves the object" do
        dislike.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true) }
          .to change { ActivityPub::Object.count(iri: note.iri) }.by(1)
      end

      it "puts the activity in the actor's inbox" do
        dislike.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true) }
          .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
      end

      it "puts the activity in the actor's notifications" do
        dislike.object = note.assign(attributed_to: actor)
        expect { post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true) }
          .to change { Notification.count(from_iri: actor.iri) }.by(1)
      end

      it "does not put the object in the actor's timeline" do
        dislike.object = note.assign(attributed_to: actor)
        expect { post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true) }
          .not_to change { Timeline.count(from_iri: actor.iri) }
      end
    end

    context "on create" do
      let_build(:note, attributed_to: other)
      let_build(:create, actor: other, object: nil, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", create.to_json_ld(true), "application/json") }

      # it's a create so the note doesn't exist
      before_each { HTTP::Client.objects << note.assign(content: "content") }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if object is not attributed to activity's actor" do
        create.object = note
        note.attributed_to = actor
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        create.object_iri = note.iri
        headers = Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", create.to_json_ld(false), "application/json")
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(false)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        create.object = note
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(HTTP::Client.last?).to be_nil
      end

      it "saves the object" do
        create.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
          .to change { ActivityPub::Object.count(iri: note.iri) }.by(1)
      end

      it "puts the activity in the actor's inbox" do
        create.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
          .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
      end

      it "does not put the activity in the actor's notifications" do
        create.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
          .not_to change { Notification.count(from_iri: actor.iri) }
      end

      it "puts the object in the actor's timeline" do
        create.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
          .to change { Timeline.count(from_iri: actor.iri) }.by(1)
      end

      context "and the object's already in the timeline" do
        let_create!(:timeline_create, owner: actor, object: note)

        it "does not put the object in the actor's timeline" do
          create.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .not_to change { Timeline.count(from_iri: actor.iri) }
        end
      end

      context "and the object's a reply to some object" do
        let_build(:object, named: parent)

        before_each do
          note.assign(in_reply_to: parent).save
        end

        it "does not put the object in the actor's timeline" do
          create.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .not_to change { Timeline.count(from_iri: actor.iri) }
        end
      end

      context "and the object's a reply to the actor's object" do
        let_create(:object, named: parent, attributed_to: actor)

        before_each do
          note.assign(in_reply_to: parent).save
        end

        it "puts the object in the actor's notifications" do
          create.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .to change { Notification.count(from_iri: actor.iri) }.by(1)
        end
      end

      context "and object mentions the actor" do
        let_build(:mention, name: "local recipient", href: actor.iri)
        let_build(:note, attributed_to: other, mentions: [mention])

        it "puts the activity in the actor's notifications" do
          create.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .to change { Notification.count(from_iri: actor.iri) }.by(1)
        end
      end

      context "and the activity is addressed to the other's followers" do
        before_each do
          other.assign(followers: "#{other.iri}/followers").save
          create.assign(to: ["#{other.iri}/followers"])
        end

        it "does not put the activity in the actor's inbox" do
          create.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .not_to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other, confirmed: true).save
          end

          it "puts the activity in the actor's inbox" do
            create.object = note
            expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
              .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
          end
        end
      end

      context "and the activity is addressed to the public collection" do
        before_each do
          create.assign(to: [PUBLIC])
        end

        it "does not put the activity in the actor's inbox" do
          create.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .not_to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other, confirmed: true).save
          end

          it "puts the activity in the actor's inbox" do
            create.object = note
            expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
              .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
          end
        end
      end

      context "signature is not valid but the remote object can be fetched" do
        let(headers) { Ktistec::Signature.sign(other, "", "{}", "") }

        before_each { create.object = note }

        it "checks for the existence of the object" do
          post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
          expect(HTTP::Client.requests).to have("GET #{note.iri}")
        end

        it "saves the object" do
          expect { post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true) }
            .to change { note.class.find?(note.iri) }.from(nil)
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
          expect(response.status_code).to eq(200)
        end
      end

      it "is successful" do
        create.object = note
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(response.status_code).to eq(200)
      end
    end

    context "on update (object)" do
      let_build(:note, attributed_to: other)
      let_build(:update, actor: other, object: nil, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", update.to_json_ld(true), "application/json") }

      # it's an update so the note already exists
      before_each { HTTP::Client.objects << note.save.assign(content: "content") }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if object is not attributed to activity's actor" do
        update.object = note
        note.attributed_to = actor
        post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        update.object_iri = note.iri
        headers = Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", update.to_json_ld(false), "application/json")
        post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(false)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        update.object = note
        post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
        expect(HTTP::Client.last?).to be_nil
      end

      it "updates the object" do
        update.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true) }
          .to change { ActivityPub::Object.find(note.iri).content }
      end

      it "puts the activity in the actor's inbox" do
        update.object = note
        expect { post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true) }
          .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
      end

      it "is successful" do
        update.object = note
        post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
        expect(response.status_code).to eq(200)
      end

      context "signature is not valid but the remote object can be fetched" do
        let(headers) { Ktistec::Signature.sign(other, "", "{}", "") }

        before_each { update.object = note }

        it "checks for the existence of the object" do
          post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
          expect(HTTP::Client.requests).to have("GET #{note.iri}")
        end

        it "updates the saved object" do
          expect { post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true) }
            .to change { note.class.find(note.id).content }.to("content")
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
          expect(response.status_code).to eq(200)
        end
      end

      context "and the object's a reply to the actor's object" do
        let_create(:object, named: parent, attributed_to: actor)

        before_each do
          note.assign(in_reply_to: parent).save
        end

        it "puts the object in the actor's notifications" do
          update.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true) }
            .to change { Notification.count(from_iri: actor.iri) }.by(1)
        end
      end

      context "and object mentions the actor" do
        let_build(:mention, name: "local recipient", href: actor.iri)
        let_build(:note, attributed_to: other, mentions: [mention])

        it "puts the activity in the actor's notifications" do
          update.object = note
          expect { post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true) }
            .to change { Notification.count(from_iri: actor.iri) }.by(1)
        end
      end
    end

    context "on update (actor)" do
      let_build(:update, actor: other, object: nil, to: [actor.iri])

      let(json_ld) { update.to_json_ld(recursive: true) }

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", json_ld, "application/json") }

      before_each { other.assign(name: "Updated Name") }

      it "returns 400 if no actor is included" do
        post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      let_create(:actor, named: :third)

      it "returns 400 if the actor is not the one being updated" do
        update.object = third
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(response.status_code).to eq(400)
      end

      it "fetches actor if remote" do
        update.object_iri = other.iri
        headers = Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", update.to_json_ld(false), "application/json")
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.last?).to match("GET #{other.iri}")
      end

      it "doesn't fetch the actor if embedded" do
        update.object = other
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.last?).to be_nil
      end

      it "updates the actor" do
        update.object = other
        expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
          .to change { ActivityPub::Actor.find(other.iri).name }.to("Updated Name")
      end

      it "puts the activity in the actor's inbox" do
        update.object = other
        expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
          .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
      end

      it "is successful" do
        update.object = other
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(response.status_code).to eq(200)
      end

      context "and the embedded actor claims a handle" do
        let(claimed) { "#{other.username}@remote" }

        # `other` is remote, so our own serializer omits `webfinger`.
        let(json_ld) do
          doc = JSON.parse(update.to_json_ld(recursive: true)).as_h
          doc["@context"] = JSON::Any.new(doc["@context"].as_a << JSON::Any.new("https://purl.archive.org/socialweb/webfinger"))
          object = doc["object"].as_h
          object["webfinger"] = JSON::Any.new(claimed)
          doc["object"] = JSON::Any.new(object)
          doc.to_json
        end

        it "stores the verified handle" do
          update.object = other
          expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
            .to change { ActivityPub::Actor.find?(other.iri).try(&.verified_handle) }
              .from(nil).to(claimed)
        end

        context "that does not verify" do
          let(claimed) { "#{other.username}@elsewhere" }

          it "does not store the handle" do
            update.object = other
            post "/actors/#{actor.username}/inbox", headers, json_ld
            expect(ActivityPub::Actor.find(other.iri).verified_handle).to be_nil
          end
        end
      end
    end

    context "on follow" do
      let_build(:follow, actor: nil, object: nil, to: [actor.iri])

      let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

      it "returns 400 if actor is missing" do
        follow.object = actor
        HTTP::Client.activities << follow
        post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if object is missing" do
        follow.actor = other
        HTTP::Client.activities << follow
        post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      context "when object is this account" do
        before_each do
          follow.actor = other
          follow.object = actor
        end

        let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", follow.to_json_ld(true), "application/json") }

        it "creates an unconfirmed follow relationship" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .to change { Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: false) }.by(1)
        end

        it "puts the activity in the actor's inbox" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
        end

        it "puts the activity in the actor's notifications" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .to change { Notification.count(from_iri: actor.iri) }.by(1)
        end

        it "does not put the object in the actor's timeline" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .not_to change { Timeline.count(from_iri: actor.iri) }
        end

        context "and activity isn't addressed" do
          before_each do
            follow.to.try(&.clear)
          end

          it "puts the activity in the actor's inbox" do
            expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
              .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
          end
        end
      end

      context "when object is not this account" do
        before_each do
          follow.actor = other
          follow.object = other
        end

        let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", follow.to_json_ld(true), "application/json") }

        it "does not create a follow relationship" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .not_to change { Relationship::Social::Follow.count }
        end

        it "puts the activity in the actor's inbox" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
        end

        it "does not put the activity in the actor's notifications" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .not_to change { Notification.count(from_iri: actor.iri) }
        end

        it "does not put the object in the actor's timeline" do
          expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
            .not_to change { Timeline.count(from_iri: actor.iri) }
        end

        context "and activity isn't addressed" do
          before_each do
            follow.to.try(&.clear)
          end

          it "puts the activity in the actor's inbox" do
            expect { post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true) }
              .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
          end
        end
      end
    end

    context "on quote request" do
      let_create(:note, named: :quoted_post, attributed_to: actor, local: true)
      let_build(:note, named: :quoting_post, attributed_to: other)
      let_build(:quote_request, actor: other, object: nil, instrument: nil)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", quote_request.to_json_ld(true), "application/json") }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, quote_request.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if object is not local" do
        quote_request.assign(object: quoting_post) # intentionally use non-local `quoting_post`
        post "/actors/#{actor.username}/inbox", headers, quote_request.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      context "and a local object" do
        before_each { quote_request.assign(object: quoted_post) }

        it "returns 400 if object is not visible" do
          quoted_post.assign(visible: false).save
          post "/actors/#{actor.username}/inbox", headers, quote_request.to_json_ld(true)
          expect(response.status_code).to eq(400)
        end

        it "accepts the quote request" do
          post "/actors/#{actor.username}/inbox", headers, quote_request.to_json_ld(true)
          expect(response.status_code).to eq(200)
        end
      end

      it "accepts the quote request" do
        quote_request.assign(object: quoted_post, instrument: quoting_post)
        post "/actors/#{actor.username}/inbox", headers, quote_request.to_json_ld(true)
        expect(response.status_code).to eq(200)
      end
    end

    context "on accept (follow)" do
      let_create!(:follow_relationship, named: :relationship, actor: actor, object: other, confirmed: false)
      let_create(:follow, actor: actor, object: other)
      let_build(:accept, actor: other, object: follow)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", accept.to_json_ld, "application/json") }

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld(recursive: false)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if it's not accepting the actor's follow" do
        follow.assign(actor: other).save
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "accepts the relationship" do
        expect { post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld }
          .to change { relationship.reload!.confirmed }
        expect(response.status_code).to eq(200)
      end

      it "accepts the relationship even if previously received" do
        accept.save
        expect { post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld }
          .to change { relationship.reload!.confirmed }
        expect(response.status_code).to eq(200)
      end
    end

    context "on accept (quote request)" do
      let_create(:quote_request, actor: actor, object: nil)
      let_build(:accept, actor: other, object: quote_request)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", accept.to_json_ld, "application/json") }

      it "returns 400 if related activity does not exist" do
        quote_request.destroy
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld(recursive: false)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if it's not accepting the actor's quote request" do
        quote_request.assign(actor: other).save
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "accepts the quote request" do
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(200)
      end

      it "accepts the quote request even if previously received" do
        accept.save
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(200)
      end
    end

    context "on reject (follow)" do
      let_create!(:follow_relationship, named: :relationship, actor: actor, object: other, confirmed: false)
      let_create(:follow, actor: actor, object: other)
      let_build(:reject, actor: other, object: follow)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", reject.to_json_ld, "application/json") }

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld(recursive: false)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if it's not rejecting the actor's follow" do
        follow.assign(actor: other).save
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "rejects the relationship" do
        expect { post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld }
          .to change { relationship.reload!.confirmed }
        expect(response.status_code).to eq(200)
      end

      it "rejects the relationship even if previously received" do
        reject.save
        expect { post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld }
          .to change { relationship.reload!.confirmed }
        expect(response.status_code).to eq(200)
      end
    end

    context "on reject (quote request)" do
      let_create(:quote_request, actor: actor, object: nil)
      let_build(:reject, actor: other, object: quote_request)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", reject.to_json_ld, "application/json") }

      it "returns 400 if related activity does not exist" do
        quote_request.destroy
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld(recursive: false)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if it's not rejecting the actor's quote request" do
        quote_request.assign(actor: other).save
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "rejects the quote request" do
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(200)
      end

      it "rejects the quote request even if previously received" do
        reject.save
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(200)
      end
    end

    context "when undoing" do
      let_create!(:follow_relationship, named: :relationship, actor: other, object: actor)
      let_build(:undo, actor: other, object: nil)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", undo.to_json_ld, "application/json") }

      context "an announce" do
        let_create(:announce, actor: other)

        before_each do
          undo.assign(object: announce)
        end

        it "returns 400 if related activity does not exist" do
          announce.destroy
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld(recursive: false)
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if the announce and undo aren't from the same actor" do
          announce.assign(actor: actor).save
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "puts the activity in the actor's inbox" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
        end

        it "marks the announce as undone" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { announce.reload!.undone_at }
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(200)
        end
      end

      context "a like" do
        let_create(:like, actor: other)

        before_each do
          undo.assign(object: like)
        end

        it "returns 400 if related activity does not exist" do
          like.destroy
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld(recursive: false)
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if the like and undo aren't from the same actor" do
          like.assign(actor: actor).save
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "puts the activity in the actor's inbox" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
        end

        it "marks the like as undone" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { like.reload!.undone_at }
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(200)
        end
      end

      context "a follow" do
        let_create(:follow, actor: other, object: actor)

        before_each do
          undo.assign(object: follow)
        end

        it "returns 400 if relationship does not exist" do
          relationship.destroy
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if related activity does not exist" do
          follow.destroy
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld(recursive: false)
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if the follow to undo isn't for this actor" do
          follow.assign(object: other).save
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if the follow and undo aren't from the same actor" do
          follow.assign(actor: actor).save
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "puts the activity in the actor's inbox" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { Relationship::Content::Inbox.count(from_iri: actor.iri) }.by(1)
        end

        it "destroys the relationship" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { Relationship::Social::Follow.count(from_iri: other.iri, to_iri: actor.iri) }.by(-1)
        end

        it "marks the follow as undone" do
          expect { post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld }
            .to change { follow.reload!.undone_at }
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
          expect(response.status_code).to eq(200)
        end
      end
    end

    context "when deleting" do
      context "an object" do
        let_create(:note, attributed_to: other)
        let_build(:delete, actor: other, object: note)

        let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", delete.to_json_ld, "application/json") }

        context "and the object is not in the database" do
          before_each { note.destroy }

          it "accepts the delete without verifying" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(response.status_code).to eq(202)
          end

          it "makes no outbound requests" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(response.status_code).to eq(202)
            expect(HTTP::Client.requests).to be_empty
          end

          it "does not save the delete" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
              .not_to change { ActivityPub::Activity::Delete.count }
          end
        end

        it "returns 400 if the object isn't from the activity's actor" do
          note.assign(attributed_to: actor).save
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "marks the object as deleted" do
          expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
            .to change { note.reload!.deleted_at }
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(200)
        end

        context "and the object was a reply to the actor's object" do
          let_create(:object, named: parent, attributed_to: actor)
          let_create!(:notification_reply, owner: actor, object: note)

          before_each do
            note.assign(in_reply_to: parent).save
          end

          it "removes the reply notification" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
              .to change { Notification.count(from_iri: actor.iri) }.by(-1)
          end
        end

        context "and the object mentioned the actor" do
          let_build(:mention, name: "local recipient", href: actor.iri)
          let_build(:note, attributed_to: other, mentions: [mention])
          let_create!(:notification_mention, owner: actor, object: note)

          it "removes the mention notification" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
              .to change { Notification.count(from_iri: actor.iri) }.by(-1)
          end
        end

        context "using a tombstone" do
          let_build(:tombstone, iri: note.iri)

          let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", delete.to_json_ld(recursive: true), "application/json") }

          before_each { delete.object = tombstone }

          it "marks the object as deleted" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true) }
              .to change { note.reload!.deleted_at }
          end

          it "succeeds" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)
            expect(response.status_code).to eq(200)
          end
        end

        context "signature is not valid but the remote object no longer exists" do
          let(headers) { Ktistec::Signature.sign(other, "", "{}", "") }

          it "checks for the existence of the object" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)
            expect(HTTP::Client.requests).to have("GET #{note.iri}")
          end

          it "marks the object as deleted" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true) }
              .to change { note.reload!.deleted_at }
          end

          it "succeeds" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)
            expect(response.status_code).to eq(200)
          end
        end
      end

      context "an actor" do
        let_build(:delete, actor: other, object: other)

        let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", delete.to_json_ld, "application/json") }

        context "and the actor is not in the database" do
          before_each { other.destroy }

          it "accepts the delete without verifying" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(response.status_code).to eq(202)
          end

          it "makes no outbound requests" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(response.status_code).to eq(202)
            expect(HTTP::Client.requests).to be_empty
          end

          it "does not save the delete" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
              .not_to change { ActivityPub::Activity::Delete.count }
          end
        end

        it "returns 400 if the actor isn't the activity's actor" do
          delete.object = actor
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "marks the actor as deleted" do
          expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
            .to change { other.reload!.deleted_at }
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(200)
        end

        context "signature is not valid but the remote actor no longer exists" do
          let(headers) { Ktistec::Signature.sign(other, "", "{}", "") }

          it "checks for the existence of the actor" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "marks the actor as deleted" do
            expect { post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld }
              .to change { other.reload!.deleted_at }
          end

          it "succeeds" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(response.status_code).to eq(200)
          end
        end
      end
    end

    context "Lemmy compatibility" do
      let_create(:group, named: :community, iri: "https://lemmy.ml/c/opensource", with_keys: true)
      let_create(:actor, named: :lemmy_user, iri: "https://lemmy.world/u/testuser")

      let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

      context "wrapped Create activity (post)" do
        let_build(:object, named: :page, attributed_to: lemmy_user)
        let_build(:create, actor: lemmy_user, object: page)
        let_build(:announce, actor: community, object_iri: create.iri)

        let(wrapped_json) do
          # manually construct Announce{Create{Page}} like Lemmy sends
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(create.to_json_ld(recursive: true)),
          }.to_json
        end

        before_each do
          # the inner Create activity needs to be fetchable for verification
          HTTP::Client.activities << create
          HTTP::Client.objects << page
        end

        it "saves the inner Create activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Activity::Create.count }.by(1)
        end

        it "saves the Object" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Object.count }.by(1)
        end

        it "does not save the Announce wrapper" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .not_to change { ActivityPub::Activity::Announce.count }
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Create activity (comment)" do
        let_build(:note, attributed_to: lemmy_user)
        let_build(:create, actor: lemmy_user, object: note)
        let_build(:announce, actor: community, object_iri: create.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(create.to_json_ld(recursive: true)),
          }.to_json
        end

        before_each do
          HTTP::Client.activities << create
          HTTP::Client.objects << note
        end

        it "saves the inner Create activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Activity::Create.count }.by(1)
        end

        it "saves the Note" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Object.count }.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      # only `Delete` is relay-trusted: a social signal (like `Like`)
      # must still be origin-verified, so the community's signature
      # does not authenticate it.

      context "wrapped Like activity" do
        let_create(:object, attributed_to: actor)
        let_build(:like, actor: lemmy_user, object: object)
        let_build(:announce, actor: community, object_iri: like.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(like.to_json_ld),
          }.to_json
        end

        let(headers) { Ktistec::Signature.sign(community, "https://test.test/actors/#{actor.username}/inbox", wrapped_json, "application/json") }

        context "served at its origin" do
          before_each { HTTP::Client.activities << like }

          it "saves the inner Like activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { ActivityPub::Activity::Like.count }.by(1)
          end

          it "does not save the Announce wrapper" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Announce.count }
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(200)
          end
        end

        context "not served at its origin" do
          it "does not save the inner Like activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Like.count }
          end

          it "does not save the Announce wrapper" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Announce.count }
          end

          it "returns 400" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(400)
          end
        end
      end

      context "wrapped Dislike activity" do
        let_create(:object, attributed_to: actor)
        let_build(:dislike, actor: lemmy_user, object: object)
        let_build(:announce, actor: community, object_iri: dislike.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(dislike.to_json_ld),
          }.to_json
        end

        before_each do
          HTTP::Client.activities << dislike
        end

        it "saves the inner Dislike activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Activity::Dislike.count }.by(1)
        end

        it "does not save the Announce wrapper" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .not_to change { ActivityPub::Activity::Announce.count }
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Update activity" do
        let_create(:object, attributed_to: lemmy_user)
        let_build(:update, actor: lemmy_user, object: object)
        let_build(:announce, actor: community, object_iri: update.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(update.to_json_ld(recursive: true)),
          }.to_json
        end

        before_each do
          HTTP::Client.activities << update
          HTTP::Client.objects << object
        end

        it "saves the inner Update activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Activity::Update.count }.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Undo activity" do
        let_create(:like, actor: lemmy_user)
        let_build(:undo, actor: lemmy_user, object: like)
        let_build(:announce, actor: community, object_iri: undo.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(undo.to_json_ld),
          }.to_json
        end

        before_each do
          HTTP::Client.activities << undo
        end

        it "saves the inner Undo activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .to change { ActivityPub::Activity::Undo.count }.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Delete activity (community relay)" do
        let_create(:actor, named: :moderator, iri: "https://lemmy.ml/u/mod")
        let_create(:object, attributed_to: lemmy_user, audience: [community.iri])
        let_build(:delete, actor: moderator, object: object)
        let_build(:announce, actor: community, object_iri: delete.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => announce.actor.iri,
            "object"   => JSON.parse(delete.to_json_ld),
          }.to_json
        end

        let(headers) { Ktistec::Signature.sign(announce.actor, "https://test.test/actors/#{actor.username}/inbox", wrapped_json, "application/json") }

        before_each { HTTP::Client.objects << object }

        context "when the community is in the audience but is not followed" do
          it "does not save the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Delete.count }
          end

          it "does not delete the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { object.reload!.deleted_at }
          end

          it "returns 400" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(400)
          end
        end

        context "when community is in the audience and is followed" do
          let_create!(:follow_relationship, actor: actor, object: community)

          it "saves the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { ActivityPub::Activity::Delete.count }.by(1)
          end

          it "deletes the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { object.reload!.deleted_at }
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(200)
          end
        end

        context "when the object is gone at its origin" do
          before_each { HTTP::Client.objects.delete(object.iri) }

          it "saves the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { ActivityPub::Activity::Delete.count }.by(1)
          end

          it "deletes the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { object.reload!.deleted_at }
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(200)
          end

          context "and the moderator is unresolvable" do
            # the moderator's instance is dead -- not cached, not
            # fetchable. the community's signature is the authentication.
            # resolving the inner actor must not gate the removal.
            let_build(:actor, named: :ghost, iri: "https://dead.example/u/ghost")
            let_build(:delete, actor: ghost, object: object)

            it "saves the Delete activity" do
              expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
                .to change { ActivityPub::Activity::Delete.count }.by(1)
            end

            it "deletes the object" do
              expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
                .to change { object.reload!.deleted_at }
            end

            it "is successful" do
              post "/actors/#{actor.username}/inbox", headers, wrapped_json
              expect(response.status_code).to eq(200)
            end
          end
        end

        context "when signed by an unrelated community" do
          let_create(:group, named: :attacker, iri: "https://evil.example/c/attacker", with_keys: true)
          let_build(:announce, actor: attacker, object_iri: delete.iri)
          let_create!(:follow_relationship, actor: actor, object: attacker)

          it "does not save the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Delete.count }
          end

          it "does not delete the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { object.reload!.deleted_at }
          end

          it "returns 400" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(400)
          end
        end

        context "when the relayer is not a Group" do
          let_create(:actor, named: :person, iri: "https://example.com/users/person", with_keys: true)
          let_create(:object, attributed_to: lemmy_user, audience: [person.iri])
          let_build(:announce, actor: person, object_iri: delete.iri)
          let_create!(:follow_relationship, actor: actor, object: person)

          it "does not save the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Delete.count }
          end

          it "does not delete the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { object.reload!.deleted_at }
          end

          it "returns 400" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(400)
          end
        end

        context "without the community's signature" do
          let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

          it "does not save the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { ActivityPub::Activity::Delete.count }
          end

          it "does not delete the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .not_to change { object.reload!.deleted_at }
          end

          it "returns 400" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(400)
          end
        end

        context "with the community key as its own document" do
          let_create!(:follow_relationship, actor: actor, object: community)

          let(key_id) { "#{community.iri}/main-key" }

          let(key_document) do
            {
              "@context"     => "https://w3id.org/security/v1",
              "id"           => key_id,
              "owner"        => community.iri,
              "publicKeyPem" => community.pem_public_key,
            }.to_json
          end

          let(headers) do
            Ktistec::Signature.sign(community, "https://test.test/actors/#{actor.username}/inbox", wrapped_json, "application/json").tap do |hdrs|
              hdrs["Signature"] = hdrs["Signature"].gsub(/keyId="[^"]*"/, %Q<keyId="#{key_id}">)
            end
          end

          before_each { HTTP::Client.cache[key_id] = key_document }

          it "retrieves the key document" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(HTTP::Client.requests).to have("GET #{key_id}")
          end

          it "saves the Delete activity" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { ActivityPub::Activity::Delete.count }.by(1)
          end

          it "deletes the object" do
            expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
              .to change { object.reload!.deleted_at }
          end

          it "is successful" do
            post "/actors/#{actor.username}/inbox", headers, wrapped_json
            expect(response.status_code).to eq(200)
          end

          context "whose owner is not the announcing community" do
            let_create(:actor, named: :other_owner, iri: "https://lemmy.ml/u/otheruser")

            let(key_document) do
              {
                "@context"     => "https://w3id.org/security/v1",
                "id"           => key_id,
                "owner"        => other_owner.iri,
                "publicKeyPem" => community.pem_public_key,
              }.to_json
            end

            it "retrieves the key document" do
              post "/actors/#{actor.username}/inbox", headers, wrapped_json
              expect(HTTP::Client.requests).to have("GET #{key_id}")
            end

            it "does not save the Delete activity" do
              expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
                .not_to change { ActivityPub::Activity::Delete.count }
            end

            it "does not delete the object" do
              expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
                .not_to change { object.reload!.deleted_at }
            end

            it "returns 400" do
              post "/actors/#{actor.username}/inbox", headers, wrapped_json
              expect(response.status_code).to eq(400)
            end
          end
        end
      end

      context "unsupported wrapped activity type" do
        let_build(:follow, actor: lemmy_user, object: actor)
        let_build(:announce, actor: community, object_iri: follow.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => JSON.parse(follow.to_json_ld),
          }.to_json
        end

        before_each do
          HTTP::Client.activities << announce
        end

        it "does not save the inner Follow activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, wrapped_json }
            .not_to change { ActivityPub::Activity::Follow.count }
        end

        it "returns 400" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(400)
        end
      end

      context "malformed wrapped activity" do
        let_build(:announce, actor: community)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type"     => "Announce",
            "id"       => announce.iri,
            "actor"    => community.iri,
            "object"   => {
              "type" => "Like",
              # missing required fields like id, actor, object
            },
          }.to_json
        end

        before_each do
          HTTP::Client.activities << announce
        end

        it "returns 400" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(400)
        end
      end

      context "regular Announce (Mastodon boost)" do
        let_create(:object, attributed_to: other)
        let_build(:announce, actor: other, object: object)

        before_each do
          HTTP::Client.objects << object
          HTTP::Client.activities << announce
        end

        let(json_ld) { announce.to_json_ld }

        it "saves the activity" do
          expect { post "/actors/#{actor.username}/inbox", headers, json_ld }
            .to change { ActivityPub::Activity::Announce.count }.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, json_ld
          expect(response.status_code).to eq(200)
        end
      end
    end
  end

  describe "GET /actors/:username/inbox" do
    it "returns 401 if not authorized" do
      get "/actors/0/inbox"
      expect(response.status_code).to eq(401)
    end

    context "with authorized" do
      let(actor) { register.actor }
      let(other) { register.actor }

      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/0/inbox"
        expect(response.status_code).to eq(404)
      end

      it "returns 403 if not the current account" do
        get "/actors/#{other.username}/inbox"
        expect(response.status_code).to eq(403)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/inbox"
        expect(response.status_code).to eq(200)
      end
    end
  end
end
