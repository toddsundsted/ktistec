require "../../src/models/activity_pub/object/note"
require "../../src/models/activity_pub/object/tombstone"
require "../../src/controllers/inboxes"

require "../spec_helper/controller"
require "../spec_helper/factory"
require "../spec_helper/network"

Spectator.describe RelationshipsController do
  setup_spec

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

    it "returns 409 if activity was already received and processed" do
      activity = Factory.create(:create)
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(recursive: true)
      expect(response.status_code).to eq(409)
    end

    # mastodon compatibility
    it "does not return 409 if the activity is accept" do
      activity = Factory.create(:accept)
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).not_to eq(409)
    end

    # mastodon compatibility
    it "does not return 409 if the activity is reject" do
      activity = Factory.create(:reject)
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).not_to eq(409)
    end

    it "returns 403 if the activity claims to be local" do
      activity.assign(iri: "https://test.test/activities/foo_bar")
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(403)
    end

    it "returns 403 if the activity's actor claims to be local" do
      activity.assign(actor_iri: actor.iri)
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(403)
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

      PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

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

      context "and the object's a reply" do
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

      PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

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
      let_create!(:follow_relationship, named: :relationship, actor: actor, object: other, confirmed: true)
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
        include Ktistec::Model(Common)

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
          include Ktistec::Model(Common)

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
          include Ktistec::Model(Common)

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
  end
end
