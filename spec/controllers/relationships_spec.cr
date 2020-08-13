require "../spec_helper"

Spectator.describe RelationshipsController do
  before_each { HTTP::Client.reset }
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  describe "POST /actors/:username/outbox" do
    let(actor) { register(with_keys: true).actor }
    let(other) { register(with_keys: true).actor }

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      post "/actors/0/outbox", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/0/outbox", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 403 if not the current account" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{other.username}/outbox", headers
        expect(response.status_code).to eq(403)
      end

      it "returns 400 if activity type is not supported" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{actor.username}/outbox", headers, "type=FooBar"
        expect(response.status_code).to eq(400)
      end

      context "on follow" do
        let(object) do
          ActivityPub::Actor.new(
            iri: "https://remote/actors/foo_bar",
            inbox: "https://remote/actors/foo_bar/inbox"
          ).save
        end

        it "returns 400 if object does not exist" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=https://remote/actors/blah_blah"
          expect(response.status_code).to eq(400)
        end

        it "redirects when successful" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"
          expect(response.status_code).to eq(302)
        end

        it "creates an unconfirmed follow relationship" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.
            to change{Relationship::Social::Follow.where(from_iri: actor.iri, to_iri: object.iri, confirmed: false).size}.by(1)
        end

        it "creates a follow activity" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.
            to change{ActivityPub::Activity::Follow.count(actor_iri: actor.iri, object_iri: object.iri)}.by(1)
        end

        it "puts the activity in the actor's outbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.
            to change{Relationship::Content::Outbox.count(from_iri: actor.iri)}.by(1)
        end

        it "sends the activity to the object's outbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"
          expect(HTTP::Client.last?).to match("POST #{object.inbox}")
        end
      end

      context "on accept" do
        let!(relationship) do
          Relationship::Social::Follow.new(
            actor: other,
            object: actor,
            confirmed: false
          ).save
        end
        let(follow) do
          ActivityPub::Activity::Follow.new(
            iri: "https://test.test/activities/follow",
            actor: other,
            object: actor
          ).save
        end

        it "returns 400 if a follow activity does not exist" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Accept&object=https://remote/activities/follow"
          expect(response.status_code).to eq(400)
        end

        it "confirms the follow relationship" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Accept&object=#{follow.iri}"}.
            to change{Relationship.find(relationship.id).confirmed}
        end

        it "creates an accept activity" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Accept&object=#{follow.iri}"}.
            to change{ActivityPub::Activity::Accept.count(actor_iri: actor.iri, object_iri: follow.iri)}.by(1)
        end

        it "puts the activity in the actor's outbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Accept&object=#{follow.iri}"}.
            to change{Relationship::Content::Outbox.count(from_iri: actor.iri)}.by(1)
        end

        it "puts the activity in the other's inbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Accept&object=#{follow.iri}"}.
            to change{Relationship::Content::Inbox.count(from_iri: other.iri)}.by(1)
        end
      end

      context "on reject" do
        let!(relationship) do
          Relationship::Social::Follow.new(
            actor: other,
            object: actor,
            confirmed: true
          ).save
        end
        let(follow) do
          ActivityPub::Activity::Follow.new(
            iri: "https://test.test/activities/follow",
            actor: other,
            object: actor
          ).save
        end

        it "returns 400 if a follow activity does not exist" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Reject&object=https://remote/activities/follow"
          expect(response.status_code).to eq(400)
        end

        it "confirms the follow relationship" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Reject&object=#{follow.iri}"}.
            to change{Relationship.find(relationship.id).confirmed}
        end

        it "creates a reject activity" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Reject&object=#{follow.iri}"}.
            to change{ActivityPub::Activity::Reject.count(actor_iri: actor.iri, object_iri: follow.iri)}.by(1)
        end

        it "puts the activity in the actor's outbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Reject&object=#{follow.iri}"}.
            to change{Relationship::Content::Outbox.count(from_iri: actor.iri)}.by(1)
        end

        it "puts the activity in the other's inbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Reject&object=#{follow.iri}"}.
            to change{Relationship::Content::Inbox.count(from_iri: other.iri)}.by(1)
        end
      end

      context "on create" do
        let!(relationship) do
          Relationship::Social::Follow.new(
            actor: other,
            object: actor,
            confirmed: true
          ).save
        end

        before_each do
          actor.assign(followers: "#{actor.iri}/followers").save
        end

        it "returns 400 if the content is missing" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Create"
          expect(response.status_code).to eq(400)
        end

        it "redirects when successful" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Create&content=this+is+a+test"
          expect(response.status_code).to eq(302)
        end

        it "creates a create activity" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Create&content=this+is+a+test"}.
            to change{ActivityPub::Activity::Create.count(actor_iri: actor.iri)}.by(1)
        end

        it "creates a note object" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Create&content=this+is+a+test"}.
            to change{ActivityPub::Object::Note.count(content: "this is a test")}.by(1)
        end

        it "puts the activity in the actor's outbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Create&content=this+is+a+test"}.
            to change{Relationship::Content::Outbox.count(from_iri: actor.iri)}.by(1)
        end

        it "puts the activity in the other's inbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Create&content=this+is+a+test"}.
            to change{Relationship::Content::Inbox.count(from_iri: other.iri)}.by(1)
        end
      end

      context "given a remote object" do
        let(object) do
          ActivityPub::Actor.new(
            iri: "https://remote/actors/foo_bar",
            inbox: "https://remote/actors/foo_bar/inbox"
          ).save
        end

        it "sends the activity to the object's inbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"
          expect(HTTP::Client.last?).to match("POST #{object.inbox}")
        end
      end

      context "given a local object" do
        let(object) do
          username = random_string
          ActivityPub::Actor.new(
            iri: "https://test.test/actors/#{username}",
            inbox: "https://test.test/actors/#{username}/inbox"
          ).save
        end

        it "puts the activity in the object's inbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.
            to change{Relationship::Content::Inbox.count(from_iri: object.iri)}.by(1)
        end
      end
    end
  end

  describe "POST /actors/:username/inbox" do
    let(actor) { register(with_keys: true).actor }
    let(other) { register(with_keys: true).actor }
    let(activity) do
      ActivityPub::Activity.new(
        iri: "https://remote/activities/foo_bar",
        actor_iri: other.iri,
      )
    end

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      post "/actors/0/inbox", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 400 if activity is not supported" do
      HTTP::Client.activities << activity
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(400)
    end

    it "ignores the activity if it already exists" do
      activity.save
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(200)
    end

    context "when unsigned" do
      before_each { HTTP::Client.activities << activity }

      it "retrieves the activity from the origin" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.requests).to have("GET #{activity.iri}")
      end

      it "saves the activity" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
          to change{ActivityPub::Activity.count}.by(1)
      end
    end

    context "when signed by remote actor" do
      before_each { HTTP::Client.actors << other.destroy }

      it "retrieves the remote actor from the origin" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.requests).to have("GET #{other.iri}")
      end

      it "does not retrieve the activity" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
      end

      it "saves the actor" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
          to change{ActivityPub::Actor.count}.by(1)
      end

      it "saves the activity" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
          to change{ActivityPub::Activity.count}.by(1)
      end
    end

    context "when signed by saved actor" do
      it "does not retrieve the actor" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
      end

      it "does not retrieve the activity" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.requests).not_to have("GET #{activity.iri}")
      end

      it "saves the activity" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
          to change{ActivityPub::Activity.count}.by(1)
      end

      context "which doesn't have a public key" do
        before_each do
          pem_public_key, other.pem_public_key = other.pem_public_key, nil
          HTTP::Client.actors << other.save
          other.pem_public_key = pem_public_key
        end

        it "retrieves the remote actor from the origin" do
          headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
          post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
          expect(HTTP::Client.requests).to have("GET #{other.iri}")
        end

        it "updates the actor's public key" do
          headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
          expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.
            to change{ActivityPub::Actor.find(other.id).pem_public_key}
        end
      end
    end

    context "on create" do
      let(note) do
        ActivityPub::Object::Note.new(
          iri: "https://remote/objects/#{random_string}",
        )
      end
      let(create) do
        ActivityPub::Activity::Create.new(
          iri: "https://remote/activities/create",
          actor: other
        )
      end

      it "returns 400 if no object is included" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "fetches object if remote" do
        create.object_iri = note.iri
        HTTP::Client.objects << note
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{ActivityPub::Object.count}.by(1)
        expect(HTTP::Client.last?).to match("GET #{note.iri}")
      end

      it "doesn't fetch the object if embedded" do
        create.object = note
        HTTP::Client.objects << note
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{ActivityPub::Object.count}.by(1)
        expect(HTTP::Client.last?).to be_nil
      end

      it "saves the object" do
        create.object = note
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{ActivityPub::Object.count}.by(1)
      end

      it "puts the activity in the actor's inbox" do
        create.object = note
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, create.to_json_ld(true)}.
          to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
      end
    end

    context "on follow" do
      let(follow) do
        ActivityPub::Activity::Follow.new(
          iri: "https://remote/activities/follow"
        )
      end

      it "returns 400 if actor is missing" do
        follow.object = actor
        HTTP::Client.activities << follow
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if object is missing" do
        follow.actor = other
        HTTP::Client.activities << follow
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)
        expect(response.status_code).to eq(400)
      end

      context "when object is this account" do
        before_each do
          follow.actor = other
          follow.object = actor
        end

        it "creates an unconfirmed follow relationship" do
          headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: false)}.by(1)
        end

        it "puts the activity in the actor's inbox" do
          headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri)}.by(1)
        end
      end

      context "when object is not this account" do
        before_each do
          follow.actor = other
          follow.object = other
        end

        it "does not create a follow relationship" do
          headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
          expect{post "/actors/#{actor.username}/inbox", headers, follow.to_json_ld(true)}.
            not_to change{Relationship::Social::Follow.count}
        end

        it "puts the activity in the actor's inbox" do
          headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
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

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "accepts the relationship" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
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

      it "returns 400 if relationship does not exist" do
        relationship.destroy
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if related activity does not exist" do
        follow.destroy
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld
        expect(response.status_code).to eq(400)
      end

      it "rejects the relationship" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, reject.to_json_ld}.
          to change{Relationship.find(relationship.id).confirmed}
        expect(response.status_code).to eq(200)
      end
    end
  end

  describe "GET /actors/:username/outbox" do
    let(actor) { register.actor }
    let(other) { register.actor }

    macro add_to_outbox(index, actor, visible = false, confirmed = true)
      let(activity{{index}}) do
        ActivityPub::Activity.new(
          iri: "https://test.test/activities/#{random_string}",
          visible: {{visible}}
        )
      end
      let!(relationship{{index}}) do
        Relationship::Content::Outbox.new(
          owner: {{actor}},
          activity: activity{{index}},
          confirmed: {{confirmed}},
          created_at: Time.utc(2016, 2, 15, 10, 20, {{index}})
        ).save
      end
    end

    add_to_outbox(1, actor, visible: true)
    add_to_outbox(2, actor, visible: false)
    add_to_outbox(3, other, visible: true)

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/actors/0/outbox", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/actors/0/outbox", headers
      expect(response.status_code).to eq(404)
    end

    context "when unauthorized" do
      it "renders only the public activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/outbox", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='activity']//a/@href").map(&.text)).to contain_exactly(activity1.iri)
      end

      it "renders only the public activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/outbox", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(activity1.iri)
      end
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "renders all activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/outbox", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='activity']//a/@href").map(&.text)).to contain_exactly(activity1.iri, activity2.iri)
      end

      it "renders all activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/outbox", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(activity1.iri, activity2.iri)
      end

      it "renders first page of activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/outbox?page=1&size=1", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='activity']//a/@href").map(&.text)).to contain_exactly(activity2.iri)
      end

      it "renders first page of activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/outbox?page=1&size=1", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("orderedItems").as_a).to contain_exactly(activity2.iri)
      end

      it "renders last page of activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/outbox?page=2&size=1", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='activity']//a/@href").map(&.text)).to contain_exactly(activity1.iri)
      end

      it "renders last page of activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/outbox?page=2&size=1", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("orderedItems").as_a).to contain_exactly(activity1.iri)
      end
    end
  end

  describe "GET /actors/:username/inbox" do
    let(actor) { register.actor }
    let(other) { register.actor }

    macro add_to_inbox(index, actor, visible = false, confirmed = true)
      let(activity{{index}}) do
        ActivityPub::Activity.new(
          iri: "https://test.test/activities/#{random_string}",
          visible: {{visible}}
        )
      end
      let!(relationship{{index}}) do
        Relationship::Content::Inbox.new(
          owner: {{actor}},
          activity: activity{{index}},
          confirmed: {{confirmed}},
          created_at: Time.utc(2016, 2, 15, 10, 20, {{index}})
        ).save
      end
    end

    add_to_inbox(1, actor, visible: true)
    add_to_inbox(2, actor, visible: false)
    add_to_inbox(3, other, visible: true)

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/actors/0/inbox", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/actors/0/inbox", headers
      expect(response.status_code).to eq(404)
    end

    context "when unauthorized" do
      it "renders only the public activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/inbox", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='activity']//a/@href").map(&.text)).to contain_exactly(activity1.iri)
      end

      it "renders only the public activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/inbox", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(activity1.iri)
      end
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "renders all activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/inbox", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='activity']//a/@href").map(&.text)).to contain_exactly(activity1.iri, activity2.iri)
      end

      it "renders all activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/inbox", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(activity1.iri, activity2.iri)
      end

      it "renders first page of activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/inbox?page=1&size=1", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[contains(@class,'activity')]//a/@href").map(&.text)).to contain_exactly(activity2.iri)
      end

      it "renders first page of activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/inbox?page=1&size=1", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("orderedItems").as_a).to contain_exactly(activity2.iri)
      end

      it "renders last page of activities" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/inbox?page=2&size=1", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[contains(@class,'activity')]//a/@href").map(&.text)).to contain_exactly(activity1.iri)
      end

      it "renders last page of activities" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/inbox?page=2&size=1", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("orderedItems").as_a).to contain_exactly(activity1.iri)
      end
    end
  end

  describe "GET /actors/:username/:relationship" do
    let(actor) { register.actor }
    let(other1) { register.actor }
    let(other2) { register.actor }

    let!(relationship1) do
      Relationship::Social::Follow.new(
        from_iri: actor.iri,
        to_iri: other1.iri,
        confirmed: true,
        visible: true
      ).save
    end
    let!(relationship2) do
      Relationship::Social::Follow.new(
        from_iri: actor.iri,
        to_iri: other2.iri
      ).save
    end
    let!(relationship3) do
      Relationship::Social::Follow.new(
        from_iri: other1.iri,
        to_iri: other2.iri
      ).save
    end

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/actors/0/following", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/actors/0/following", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 401 if relationship type is not supported" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/actors/#{actor.username}/foobar", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if relationship type is not supported" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/actors/#{actor.username}/foobar", headers
      expect(response.status_code).to eq(401)
    end

    context "when unauthorized" do
      it "renders only the related public actors" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='actor']//a/@href").map(&.text)).to eq(["/remote/actors/#{other1.id}"])
      end

      it "renders only the related public actors" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems")).to eq([other1.iri])
      end
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "renders all the related actors" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='actor']//a/@href").map(&.text)).to contain_exactly("/remote/actors/#{other1.id}", "/remote/actors/#{other2.id}")
      end

      it "renders all the related actors" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(other1.iri, other2.iri)
      end

      it "renders only the related public actors" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{other1.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='actor']//a/@href")).to be_empty
      end

      it "renders only the related public actors" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{other1.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
      end
    end
  end

  describe "DELETE /actors/:username/:relationship/:id" do
    let(actor) { register.actor }
    let(other) { register.actor }

    let!(relationship) do
      Relationship::Social::Follow.new(
        from_iri: actor.iri,
        to_iri: other.iri
      ).save
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      delete "/actors/0/following/0", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      delete "/actors/0/following/0", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "deletes the relationship and redirects" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        expect{delete "/actors/#{actor.username}/following/#{relationship.id}", headers}.
          to change{Relationship.count}.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "deletes the relationship and redirects" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        expect{delete "/actors/#{actor.username}/following/#{relationship.id}", headers}.
          to change{Relationship.count}.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "returns 403 if not the current account" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        delete "/actors/#{other.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(403)
      end

      it "returns 403 if not the current account" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        delete "/actors/#{other.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(403)
      end

      it "returns 400 if relationship type is not supported" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        delete "/actors/#{actor.username}/foobar/#{relationship.id}", headers
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if relationship type is not supported" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        delete "/actors/#{actor.username}/foobar/#{relationship.id}", headers
        expect(response.status_code).to eq(400)
      end

      it "returns 403 if relationship does not belong to current account" do
        relationship = Relationship::Social::Follow.new(from_iri: other.iri, to_iri: other.iri).save
        headers = HTTP::Headers{"Accept" => "text/html"}
        delete "/actors/#{actor.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(403)
      end

      it "returns 403 if relationship does not belong to current account" do
        relationship = Relationship::Social::Follow.new(from_iri: other.iri, to_iri: other.iri).save
        headers = HTTP::Headers{"Accept" => "application/json"}
        delete "/actors/#{actor.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(403)
      end
    end
  end
end
