require "../spec_helper"

Spectator.describe RelationshipsController do
  setup_spec

  describe "POST /actors/:username/inbox" do
    let!(actor) { register(with_keys: true).actor }
    let(other) { register(with_keys: true).actor }
    let(activity) do
      ActivityPub::Activity.new(
        iri: "https://remote/activities/foo_bar",
        actor_iri: other.iri,
      )
    end

    let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }
    let(signed_headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge(headers) }

    it "returns 404 if not found" do
      post "/actors/0/inbox", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 409 if activity already exists" do
      activity.save
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(409)
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
      let(note) do
        ActivityPub::Object::Note.new(
          iri: "https://remote/objects/note"
        )
      end
      let(activity) do
        ActivityPub::Activity::Create.new(
          iri: "https://remote/activities/create",
          actor: other,
          object: note
        )
      end

      before_each { HTTP::Client.activities << activity }

      it "retrieves the activity from the origin" do
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(recursive: true)
        expect(HTTP::Client.requests).to have("GET #{activity.iri}")
      end

      it "saves the activity" do
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(recursive: true)}.
          to change{ActivityPub::Activity.count}.by(1)
      end

      context "and the actor is remote" do
        before_each { HTTP::Client.actors << other.destroy }

        it "retrieves the actor from the origin" do
          post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(recursive: true)
          expect(HTTP::Client.requests).to have("GET #{other.iri}")
        end

        it "saves the actor" do
          expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld(recursive: true)}.
            to change{ActivityPub::Actor.count}.by(1)
        end
      end
    end

    context "when signed" do
      let(note) do
        ActivityPub::Object::Note.new(
          iri: "https://remote/objects/note"
        )
      end
      let(activity) do
        ActivityPub::Activity::Create.new(
          iri: "https://remote/activities/create",
          actor_iri: other.iri,
          object_iri: note.iri
        )
      end

      before_each { HTTP::Client.objects << note }

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

      it "does not retrieve the activity" do
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
      end

      it "saves the activity" do
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
          to change{ActivityPub::Activity.count}.by(1)
      end

      context "by remote actor" do
        before_each { HTTP::Client.actors << other.destroy }

        it "retrieves the remote actor from the origin" do
          post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
          expect(HTTP::Client.requests).to have("GET #{other.iri}")
        end

        it "saves the actor" do
          expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
            to change{ActivityPub::Actor.count}.by(1)
        end
      end

      context "by saved actor" do
        it "does not retrieve the actor" do
          post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
          expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
        end

        context "which doesn't have a public key" do
          before_each do
            pem_public_key, other.pem_public_key = other.pem_public_key, nil
            HTTP::Client.actors << other.save
            other.pem_public_key = pem_public_key
          end

          it "retrieves the remote actor from the origin" do
            post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "updates the actor's public key" do
            expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
              to change{ActivityPub::Actor.find(other.id).pem_public_key}
          end
        end

        context "which can't authenticate the activity" do
          before_each do
            pem_public_key, other.pem_public_key = other.pem_public_key, ""
            HTTP::Client.actors << other.save
            other.pem_public_key = pem_public_key
          end

          it "retrieves the activity from the origin" do
            post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
            expect(HTTP::Client.requests).to have("GET #{activity.iri}")
          end

          it "returns 400 if the activity can't be verified" do
            post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
            expect(JSON.parse(response.body)["msg"]).to eq("can't be verified")
            expect(response.status_code).to eq(400)
          end
        end
      end
    end

    context "on announce" do
      let(note) do
        ActivityPub::Object::Note.new(
          iri: "https://remote/objects/#{random_string}",
          attributed_to: other
        )
      end
      let(announce) do
        ActivityPub::Activity::Announce.new(
          iri: "https://remote/activities/announce",
          actor: other,
          to: [actor.iri]
        )
      end

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

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
    end

    context "on create" do
      let(note) do
        ActivityPub::Object::Note.new(
          iri: "https://remote/objects/#{random_string}"
        )
      end
      let(create) do
        ActivityPub::Activity::Create.new(
          iri: "https://remote/activities/create",
          actor: other,
          to: [actor.iri]
        )
      end

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

      it "returns 400 if no object is included" do
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        create.object_iri = note.iri
        HTTP::Client.objects << note
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        create.object = note
        HTTP::Client.objects << note
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
    end

    context "on follow" do
      let(follow) do
        ActivityPub::Activity::Follow.new(
          iri: "https://remote/activities/follow",
          to: [actor.iri]
        )
      end

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

        let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

        it "creates an unconfirmed follow relationship" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: false)}.by(1)
        end

        it "puts the activity in the actor's inbox" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end
      end

      context "when object is not this account" do
        before_each do
          follow.actor = other
          follow.object = other
        end

        let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

        it "does not create a follow relationship" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            not_to change{Relationship::Social::Follow.count}
        end

        it "puts the activity in the actor's inbox" do
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end
      end
    end

    context "on accept" do
      let!(relationship) do
        Relationship::Social::Follow.new(
          actor: actor,
          object: other,
          confirmed: false
        ).save
      end
      let(follow) do
        ActivityPub::Activity::Follow.new(
          iri: "https://test.test/activities/follow",
          actor: actor,
          object: other
        ).save
      end
      let(accept) do
        ActivityPub::Activity::Accept.new(
          iri: "https://remote/activities/accept",
          actor: other,
          object: follow
        )
      end

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if it's not accepting the actor's follow" do
        follow.assign(actor: other).save
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "accepts the relationship" do
        expect{post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld}.
          to change{Relationship.find(relationship.id).confirmed}
        expect(response.status_code).to eq(200)
      end
    end

    context "on reject" do
      let!(relationship) do
        Relationship::Social::Follow.new(
          actor: actor,
          object: other,
          confirmed: true
        ).save
      end
      let(follow) do
        ActivityPub::Activity::Follow.new(
          iri: "https://test.test/activities/follow",
          actor: actor,
          object: other
        ).save
      end
      let(reject) do
        ActivityPub::Activity::Reject.new(
          iri: "https://remote/activities/reject",
          actor: other,
          object: follow
        )
      end

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if it's not rejecting the actor's follow" do
        follow.assign(actor: other).save
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "rejects the relationship" do
        expect{post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld}.
          to change{Relationship.find(relationship.id).confirmed}
        expect(response.status_code).to eq(200)
      end
    end

    context "on undo" do
      let!(relationship) do
        Relationship::Social::Follow.new(
          actor: other,
          object: actor
        ).save
      end
      let(follow) do
        ActivityPub::Activity::Follow.new(
          iri: "https://test.test/activities/follow",
          actor: other,
          object: actor
        ).save
      end
      let(undo) do
        ActivityPub::Activity::Undo.new(
          iri: "https://remote/activities/undo",
          actor: other,
          object: follow
        )
      end

      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
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

      it "destroys the relationship" do
        expect{post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld}.
          to change{Relationship::Social::Follow.count(from_iri: other.iri, to_iri: actor.iri)}.by(-1)
      end

      it "succeeds" do
        post "/actors/#{actor.username}/inbox", headers, undo.to_json_ld
        expect(response.status_code).to eq(200)
      end
    end

    context "on delete" do
      let(headers) { Ktistec::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"}) }

      context "object" do
        let(note) do
          ActivityPub::Object::Note.new(
            iri: "https://remote/objects/#{random_string}",
            attributed_to: other
          ).save
        end
        let(delete) do
          ActivityPub::Activity::Delete.new(
            iri: "https://remote/activities/delete",
            actor: other,
            object: note
          )
        end

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
            to change{DeletedObject.find(note.id).deleted_at}
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(200)
        end

        context "using a tombstone" do
          let(tombstone) do
            ActivityPub::Object::Tombstone.new(
              iri: note.iri
            )
          end

          before_each { delete.object = tombstone }

          it "marks the object as deleted" do
            expect{post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)}.
              to change{DeletedObject.find(note.id).deleted_at}
          end

          it "succeeds" do
            post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld(recursive: true)
            expect(response.status_code).to eq(200)
          end
        end
      end

      context "actor" do
        let(delete) do
          ActivityPub::Activity::Delete.new(
            iri: "https://remote/activities/delete",
            actor: other,
            object: other
          )
        end

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
            to change{DeletedActor.find(other.id).deleted_at}
        end

        it "succeeds" do
          post "/actors/#{actor.username}/inbox", headers, delete.to_json_ld
          expect(response.status_code).to eq(200)
        end
      end
    end
  end
end
