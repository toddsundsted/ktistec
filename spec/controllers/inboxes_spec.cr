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

    it "returns 404 if account not found" do
      post "/actors/0/inbox", headers
      expect(response.status_code).to eq(404)
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

    it "returns 400 if activity can't be verified" do
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(JSON.parse(response.body)["msg"]).to eq("can't be verified")
      expect(response.status_code).to eq(400)
    end

    it "returns 200 if activity was already received and processed" do
      activity = Factory.create(:create)
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(recursive: true)
      expect(response.status_code).to eq(200)
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
      expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
        not_to change{ActivityPub::Activity.count}
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
        expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
          to change{ActivityPub::Activity.count}.by(1)
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
          expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
            to change{ActivityPub::Actor.count}.by(1)
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
            expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
              to change{ActivityPub::Actor.count}.by(1)
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
            expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
              to change{ActivityPub::Actor.count}.by(1)
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

      it "does not retrieve the activity from the origin" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
      end

      it "does not retrieve the actor from the origin" do
        post "/actors/#{actor.username}/inbox", headers, json_ld
        expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
      end

      it "saves the activity" do
        expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
          to change{ActivityPub::Activity.count}.by(1)
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
          expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
            to change{ActivityPub::Actor.count}.by(1)
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
            expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
              to change{ActivityPub::Actor.count}.by(1)
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
            expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
              to change{ActivityPub::Actor.count}.by(1)
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
            expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
              to change{ActivityPub::Actor.find(other.id).pem_public_key}
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
    end

    context "when the other actor is down" do
      let_build(:activity, actor: other, to: [actor.iri])

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", activity.to_json_ld(true), "application/json") }

      before_each { other.down! }

      it "marks the actor as up" do
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(true)}.
          to change{other.reload!.up?}.to(true)
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
        expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
          to change{ActivityPub::Object.count(iri: note.iri)}.by(1)
      end

      it "puts the activity in the actor's inbox" do
        announce.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
          to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
      end

      it "puts the activity in the actor's notifications" do
        announce.object = note.assign(attributed_to: actor)
        expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
          to change{Notification.count(from_iri: actor.iri)}.by(1)
      end

      it "puts the object in the actor's timeline" do
        announce.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
          to change{Timeline.count(from_iri: actor.iri)}.by(1)
      end

      context "and the object's already in the timeline" do
        let_create!(:timeline, owner: actor, object: note)

        it "does not put the object in the actor's timeline" do
          announce.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
            not_to change{Timeline.count(from_iri: actor.iri)}
        end
      end

      context "and the object's a reply" do
        before_each do
          note.assign(
            in_reply_to: Factory.build(:object)
          ).save
        end

        it "puts the object in the actor's timeline" do
          announce.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
            to change{Timeline.count(from_iri: actor.iri)}.by(1)
        end
      end

      context "and the activity is addressed to the other's followers" do
        before_each do
          other.assign(followers: "#{other.iri}/followers").save
          announce.assign(to: ["#{other.iri}/followers"])
        end

        it "does not put the activity in the actor's inbox" do
          announce.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
            not_to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other).save
          end

          it "puts the activity in the actor's inbox" do
            announce.object = note
            expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
          end
        end
      end

      context "and the activity is addressed to the public collection" do
        before_each do
          announce.assign(to: [PUBLIC])
        end

        it "does not put the activity in the actor's inbox" do
          announce.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
            not_to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other).save
          end

          it "puts the activity in the actor's inbox" do
            announce.object = note
            expect{post "/actors/#{actor.username}/inbox", headers, announce.to_json_ld(true)}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
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
        expect{post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)}.
          to change{ActivityPub::Object.count(iri: note.iri)}.by(1)
      end

      it "puts the activity in the actor's inbox" do
        like.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)}.
          to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
      end

      it "puts the activity in the actor's notifications" do
        like.object = note.assign(attributed_to: actor)
        expect{post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)}.
          to change{Notification.count(from_iri: actor.iri)}.by(1)
      end

      it "does not put the object in the actor's timeline" do
        like.object = note.assign(attributed_to: actor)
        expect{post "/actors/#{actor.username}/inbox", headers, like.to_json_ld(true)}.
          not_to change{Timeline.count(from_iri: actor.iri)}
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
        expect{post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)}.
          to change{ActivityPub::Object.count(iri: note.iri)}.by(1)
      end

      it "puts the activity in the actor's inbox" do
        dislike.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)}.
          to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
      end

      it "puts the activity in the actor's notifications" do
        dislike.object = note.assign(attributed_to: actor)
        expect{post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)}.
          to change{Notification.count(from_iri: actor.iri)}.by(1)
      end

      it "does not put the object in the actor's timeline" do
        dislike.object = note.assign(attributed_to: actor)
        expect{post "/actors/#{actor.username}/inbox", headers, dislike.to_json_ld(true)}.
          not_to change{Timeline.count(from_iri: actor.iri)}
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
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{ActivityPub::Object.count(iri: note.iri)}.by(1)
      end

      it "puts the activity in the actor's inbox" do
        create.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
      end

      it "does not put the activity in the actor's notifications" do
        create.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          not_to change{Notification.count(from_iri: actor.iri)}
      end

      it "puts the object in the actor's timeline" do
        create.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{Timeline.count(from_iri: actor.iri)}.by(1)
      end

      context "and the object's already in the timeline" do
        let_create!(:timeline, owner: actor, object: note)

        it "does not put the object in the actor's timeline" do
          create.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            not_to change{Timeline.count(from_iri: actor.iri)}
        end
      end

      context "and the object's a reply to some object" do
        before_each do
          note.assign(
            in_reply_to: Factory.build(:object)
          ).save
        end

        it "does not put the object in the actor's timeline" do
          create.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            not_to change{Timeline.count(from_iri: actor.iri)}
        end
      end

      context "and the object's a reply to the actor's object" do
        before_each do
          note.assign(
            in_reply_to: Factory.create(:object, attributed_to: actor)
          ).save
        end

        it "puts the object in the actor's notifications" do
          create.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            to change{Notification.count(from_iri: actor.iri)}.by(1)
        end
      end

      context "and object mentions the actor" do
        let_build(:note, attributed_to: other, mentions: [Factory.build(:mention, name: "local recipient", href: actor.iri)])

        it "puts the activity in the actor's notifications" do
          create.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            to change{Notification.count(from_iri: actor.iri)}.by(1)
        end
      end

      context "and the activity is addressed to the other's followers" do
        before_each do
          other.assign(followers: "#{other.iri}/followers").save
          create.assign(to: ["#{other.iri}/followers"])
        end

        it "does not put the activity in the actor's inbox" do
          create.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            not_to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other).save
          end

          it "puts the activity in the actor's inbox" do
            create.object = note
            expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
          end
        end
      end

      context "and the activity is addressed to the public collection" do
        before_each do
          create.assign(to: [PUBLIC])
        end

        it "does not put the activity in the actor's inbox" do
          create.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            not_to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}
        end

        context "and the actor follows other" do
          before_each do
            actor.follow(other).save
          end

          it "puts the activity in the actor's inbox" do
            create.object = note
            expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
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
          expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
            to change{note.class.find?(note.iri)}.from(nil)
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

    context "on update" do
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
        expect{post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)}.
          to change{ActivityPub::Object.find(note.iri).content}
      end

      it "puts the activity in the actor's inbox" do
        update.object = note
        expect{post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)}.
          to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
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
          expect{post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)}.
            to change{note.class.find(note.id).content}.to("content")
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)
          expect(response.status_code).to eq(200)
        end
      end

      context "and the object's a reply to the actor's object" do
        before_each do
          note.assign(
            in_reply_to: Factory.create(:object, attributed_to: actor)
          ).save
        end

        it "puts the object in the actor's notifications" do
          update.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)}.
            to change{Notification.count(from_iri: actor.iri)}.by(1)
        end
      end

      context "and object mentions the actor" do
        let_build(:note, attributed_to: other, mentions: [Factory.build(:mention, name: "local recipient", href: actor.iri)])

        it "puts the activity in the actor's notifications" do
          update.object = note
          expect{post "/actors/#{actor.username}/inbox", headers, update.to_json_ld(true)}.
            to change{Notification.count(from_iri: actor.iri)}.by(1)
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
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: false)}.by(1)
        end

        it "puts the activity in the actor's inbox" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end

        it "puts the activity in the actor's notifications" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Notification.count(from_iri: actor.iri)}.by(1)
        end

        it "does not put the object in the actor's timeline" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            not_to change{Timeline.count(from_iri: actor.iri)}
        end

        context "and activity isn't addressed" do
          before_each do
            follow.to.try(&.clear)
          end

          it "puts the activity in the actor's inbox" do
            expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
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
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            not_to change{Relationship::Social::Follow.count}
        end

        it "puts the activity in the actor's inbox" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end

        it "does not put the activity in the actor's notifications" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            not_to change{Notification.count(from_iri: actor.iri)}
        end

        it "does not put the object in the actor's timeline" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            not_to change{Timeline.count(from_iri: actor.iri)}
        end

        context "and activity isn't addressed" do
          before_each do
            follow.to.try(&.clear)
          end

          it "puts the activity in the actor's inbox" do
            expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
          end
        end
      end
    end

    context "on accept" do
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
        expect{post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld}.
          to change{relationship.reload!.confirmed}
        expect(response.status_code).to eq(200)
      end

      it "accepts the relationship even if previously received" do
        accept.save
        expect{post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld}.
          to change{relationship.reload!.confirmed}
        expect(response.status_code).to eq(200)
      end
    end

    context "on reject" do
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
        expect{post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld}.
          to change{relationship.reload!.confirmed}
        expect(response.status_code).to eq(200)
      end

      it "rejects the relationship even if previously received" do
        reject.save
        expect{post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld}.
          to change{relationship.reload!.confirmed}
        expect(response.status_code).to eq(200)
      end
    end

    context "when undoing" do
      let_create!(:follow_relationship, named: :relationship, actor: other, object: actor)
      let_build(:undo, actor: other, object: nil)

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", undo.to_json_ld, "application/json") }

      class ::UndoneActivity
        include Ktistec::Model
        include Ktistec::Model::Common

        @@table_name = "activities"

        @[Persistent]
        property undone_at : Time?
      end

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
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end

        it "marks the announce as undone" do
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{announce.reload!.undone_at}
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
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end

        it "marks the like as undone" do
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{like.reload!.undone_at}
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
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end

        it "destroys the relationship" do
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{Relationship::Social::Follow.count(from_iri: other.iri, to_iri: actor.iri)}.by(-1)
        end

        it "marks the follow as undone" do
          expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
            to change{follow.reload!.undone_at}
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

        class ::DeletedObject
          include Ktistec::Model
          include Ktistec::Model::Common

          @@table_name = "objects"

          @[Persistent]
          property deleted_at : Time?
        end

        it "returns 400 if the object does not exist" do
          note.destroy
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if the object isn't from the activity's actor" do
          note.assign(attributed_to: actor).save
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "marks the object as deleted" do
          expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld}.
            to change{note.reload!.deleted_at}
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(200)
        end

        context "and the object was a reply to the actor's object" do
          before_each do
            note.assign(
              in_reply_to: Factory.create(:object, attributed_to: actor)
            ).save
            Factory.create(:notification_reply, owner: actor, object: note)
          end

          it "removes the reply notification" do
            expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld}.
              to change{Notification.count(from_iri: actor.iri)}.by(-1)
          end
        end

        context "and the object mentioned the actor" do
          let_build(:note, attributed_to: other, mentions: [Factory.build(:mention, name: "local recipient", href: actor.iri)])

          before_each do
            Factory.create(:notification_mention, owner: actor, object: note)
          end

          it "removes the mention notification" do
            expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld}.
              to change{Notification.count(from_iri: actor.iri)}.by(-1)
          end
        end

        context "using a tombstone" do
          let_build(:tombstone, iri: note.iri)

          let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox", delete.to_json_ld(recursive: true), "application/json") }

          before_each { delete.object = tombstone }

          it "marks the object as deleted" do
            expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)}.
              to change{note.reload!.deleted_at}
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
            expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)}.
              to change{note.reload!.deleted_at}
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

        class ::DeletedActor
          include Ktistec::Model
          include Ktistec::Model::Common

          @@table_name = "actors"

          @[Persistent]
          property deleted_at : Time?
        end

        it "returns 400 if the actor does not exist" do
          other.destroy
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "returns 400 if the actor isn't the activity's actor" do
          delete.object = actor
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(400)
        end

        it "marks the actor as deleted" do
          expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld}.
            to change{other.reload!.deleted_at}
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
            expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld}.
              to change{other.reload!.deleted_at}
          end

          it "succeeds" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
            expect(response.status_code).to eq(200)
          end
        end
      end
    end

    context "Lemmy compatibility" do
      let_create(:actor, named: :community, iri: "https://lemmy.ml/c/opensource")
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
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(create.to_json_ld(recursive: true))
          }.to_json
        end

        before_each do
          # the inner Create activity needs to be fetchable for verification
          HTTP::Client.activities << create
          HTTP::Client.objects << page
        end

        it "saves the inner Create activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Create.count}.by(1)
        end

        it "saves the Object" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Object.count}.by(1)
        end

        it "does not save the Announce wrapper" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            not_to change{ActivityPub::Activity::Announce.count}
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
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(create.to_json_ld(recursive: true))
          }.to_json
        end

        before_each do
          HTTP::Client.activities << create
          HTTP::Client.objects << note
        end

        it "saves the inner Create activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Create.count}.by(1)
        end

        it "saves the Note" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Object.count}.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Like activity" do
        let_create(:object, attributed_to: actor)
        let_build(:like, actor: lemmy_user, object: object)
        let_build(:announce, actor: community, object_iri: like.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(like.to_json_ld)
          }.to_json
        end

        before_each do
          HTTP::Client.activities << like
        end

        it "saves the inner Like activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Like.count}.by(1)
        end

        it "does not save the Announce wrapper" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            not_to change{ActivityPub::Activity::Announce.count}
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Dislike activity" do
        let_create(:object, attributed_to: actor)
        let_build(:dislike, actor: lemmy_user, object: object)
        let_build(:announce, actor: community, object_iri: dislike.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(dislike.to_json_ld)
          }.to_json
        end

        before_each do
          HTTP::Client.activities << dislike
        end

        it "saves the inner Dislike activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Dislike.count}.by(1)
        end

        it "does not save the Announce wrapper" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            not_to change{ActivityPub::Activity::Announce.count}
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
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(update.to_json_ld(recursive: true))
          }.to_json
        end

        before_each do
          HTTP::Client.activities << update
          HTTP::Client.objects << object
        end

        it "saves the inner Update activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Update.count}.by(1)
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
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(undo.to_json_ld)
          }.to_json
        end

        before_each do
          HTTP::Client.activities << undo
        end

        it "saves the inner Undo activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Undo.count}.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "wrapped Delete activity" do
        let_create(:actor, named: :lemmy_user_with_keys, iri: "https://lemmy.world/u/testuser", with_keys: true)  # WHY???????
        let_create(:object, attributed_to: lemmy_user_with_keys)
        let_build(:delete, actor: lemmy_user_with_keys, object: object)
        let_build(:announce, actor: community, object_iri: delete.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(delete.to_json_ld)
          }.to_json
        end

        let(headers) { Ktistec::Signature.sign(lemmy_user_with_keys, "https://test.test/actors/#{actor.username}/inbox", wrapped_json, "application/json") }

        it "saves the inner Delete activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            to change{ActivityPub::Activity::Delete.count}.by(1)
        end

        it "is successful" do
          post "/actors/#{actor.username}/inbox", headers, wrapped_json
          expect(response.status_code).to eq(200)
        end
      end

      context "unsupported wrapped activity type" do
        let_build(:follow, actor: lemmy_user, object: actor)
        let_build(:announce, actor: community, object_iri: follow.iri)

        let(wrapped_json) do
          {
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => JSON.parse(follow.to_json_ld)
          }.to_json
        end

        before_each do
          HTTP::Client.activities << announce
        end

        it "does not save the inner Follow activity" do
          expect{post "/actors/#{actor.username}/inbox", headers, wrapped_json}.
            not_to change{ActivityPub::Activity::Follow.count}
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
            "type" => "Announce",
            "id" => announce.iri,
            "actor" => community.iri,
            "object" => {
              "type" => "Like",
              # missing required fields like id, actor, object
            }
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
          expect{post "/actors/#{actor.username}/inbox", headers, json_ld}.
            to change{ActivityPub::Activity::Announce.count}.by(1)
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
