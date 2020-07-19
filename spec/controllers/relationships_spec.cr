require "../spec_helper"

Spectator.describe RelationshipsController do
  before_each { HTTP::Client.reset }
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  describe "POST /actors/:username/outbox" do
    let(actor) { register(with_keys: true).actor }
    let(other) { register(with_keys: true).actor }
    let(object) do
      ActivityPub::Actor.new(
        iri: "https://remote/actors/foo_bar",
        inbox: "https://remote/actors/foo_bar/inbox"
      ).save
    end

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

      context "when following" do
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
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.to change{Relationship::Social::Follow.where(confirmed: false).size}.by(1)
        end

        it "creates a follow activity" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.to change{ActivityPub::Activity::Follow.count}.by(1)
        end

        it "puts the activity in the actor's outbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.to change{Relationship::Content::Outbox.count}.by(1)
        end
      end

      context "given a remote object" do
        it "sends the activity to the object's inbox" do
          headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
          post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"
          expect(HTTP::Client.last).to match("POST #{object.inbox}")
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
          expect{post "/actors/#{actor.username}/outbox", headers, "type=Follow&object=#{object.iri}"}.to change{Relationship::Content::Inbox.count}.by(1)
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

    it "ignores the activity if it already exists" do
      activity.save
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(200)
    end

    it "returns 400 if activity is not supported" do
      headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
      post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
      expect(response.status_code).to eq(400)
    end

    context "when unsigned" do
      it "retrieves the activity from the origin" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.last).to match("GET https://remote/activities/foo_bar")
      end

      it "saves the activity" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.to change{ActivityPub::Activity.count}.by(1)
      end
    end

    context "when signed by remote actor" do
      before_each { HTTP::Client.actors << other.destroy }

      it "fetches the remote actor from the origin" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.last).to match("GET #{other.iri}")
      end

      it "saves the actor" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.to change{ActivityPub::Actor.count}.by(1)
      end

      it "saves the activity" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.to change{ActivityPub::Activity.count}.by(1)
      end
    end

    context "when signed by local actor" do
      it "does not fetch the actor" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld
        expect(HTTP::Client.last).to be_nil
      end

      it "does not save the actor" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.not_to change{ActivityPub::Actor.count}
      end

      it "saves the activity" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, activity.to_json_ld}.to change{ActivityPub::Activity.count}.by(1)
      end
    end

    context "when accepting" do
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
        expect{post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld}.to change{Relationship.find(relationship.id).confirmed}
        expect(response.status_code).to eq(200)
      end
    end

    context "when rejecting" do
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
      let(accept) do
        ActivityPub::Activity::Reject.new(
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

      it "rejects the relationship" do
        headers = Balloon::Signature.sign(other, "https://test.test/actors/#{actor.username}/inbox").merge!(HTTP::Headers{"Content-Type" => "application/json"})
        expect{post "/actors/#{actor.username}/inbox", headers, accept.to_json_ld}.to change{Relationship.find(relationship.id).confirmed}
        expect(response.status_code).to eq(200)
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

    it "returns 400 if relationship type is not supported" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/actors/#{actor.username}/foobar", headers
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if relationship type is not supported" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/actors/#{actor.username}/foobar", headers
      expect(response.status_code).to eq(400)
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
        expect(JSON.parse(response.body).dig("items")).to eq(["/remote/actors/#{other1.id}"])
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
        expect(JSON.parse(response.body).dig("items").as_a).to contain_exactly("/remote/actors/#{other1.id}", "/remote/actors/#{other2.id}")
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
        expect(JSON.parse(response.body).dig("items").as_a).to be_empty
      end
    end
  end

  describe "POST /actors/:username/:relationship" do
    let!(actor) { register.actor }
    let!(other) { register.actor }

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      post "/actors/0/following", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      post "/actors/0/following", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "creates a relationship and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        expect{post "/actors/#{actor.username}/following", headers, "iri=#{other.iri}"}.to change{Relationship.count}.by(1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "creates a relationship and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        expect{post "/actors/#{actor.username}/following", headers, {iri: other.iri}.to_json}.to change{Relationship.count}.by(1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "returns 403 if not the current account" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{other.username}/following", headers
        expect(response.status_code).to eq(403)
      end

      it "returns 403 if not the current account" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{other.username}/following", headers
        expect(response.status_code).to eq(403)
      end

      it "returns 400 if relationship type is not supported" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{actor.username}/foobar", headers, "iri=#{other.iri}"
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if relationship type is not supported" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/foobar", headers, {iri: other.iri}.to_json
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if other does not exist" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{actor.username}/following", headers, "iri=foobar"
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if other does not exist" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/following", headers, {iri: "foobar"}.to_json
        expect(response.status_code).to eq(400)
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
        expect{delete "/actors/#{actor.username}/following/#{relationship.id}", headers}.to change{Relationship.count}.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "deletes the relationship and redirects" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        expect{delete "/actors/#{actor.username}/following/#{relationship.id}", headers}.to change{Relationship.count}.by(-1)
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
