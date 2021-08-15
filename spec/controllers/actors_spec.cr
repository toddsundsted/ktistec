require "../../src/controllers/actors"

require "../spec_helper/controller"

Spectator.describe ActorsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(actor) { register.actor }

  describe "GET /actors/:username" do
    it "returns 404 if not found" do
      get "/actors/missing", ACCEPT_HTML
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      get "/actors/missing", ACCEPT_JSON
      expect(response.status_code).to eq(404)
    end

    it "returns 200 if found" do
      get "/actors/#{actor.username}", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "returns 200 if found" do
      get "/actors/#{actor.username}", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    it "responds with HTML" do
      get "/actors/#{actor.username}", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
    end

    it "responds with JSON" do
      get "/actors/#{actor.username}", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("type")).to be_truthy
    end
  end

  describe "GET /actors/:username/public-posts" do
    it "returns 404 if not found" do
      get "/actors/missing/public-posts", ACCEPT_HTML
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      get "/actors/missing/public-posts", ACCEPT_JSON
      expect(response.status_code).to eq(404)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    let(object) do
      ActivityPub::Object.new(
        iri: "https://remote/objects/#{random_string}",
        attributed_to: actor,
        visible: true
      )
    end
    let(create) do
      ActivityPub::Activity::Create.new(
        iri: "https://remote/activities/#{random_string}",
        actor: actor,
        object: object,
        created_at: Time.utc(2016, 2, 15, 10, 20, 0)
      )
    end
    let(announce) do
      ActivityPub::Activity::Announce.new(
        iri: "https://remote/activities/#{random_string}",
        actor: actor,
        object: object,
        created_at: Time.utc(2016, 2, 15, 10, 20, 1)
      )
    end

    context "given a create" do
      before_each do
        Relationship::Content::Outbox.new(
          owner: actor,
          activity: create
        ).save
      end

      it "renders the object's create aspect" do
        get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article/@class")).to contain_exactly("event activity-create")
      end
    end

    context "given an announce" do
      before_each do
        Relationship::Content::Outbox.new(
          owner: actor,
          activity: announce
        ).save
      end

      it "renders the object's announce aspect" do
        get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article/@class")).to contain_exactly("event activity-announce")
      end
    end

    context "given a create and an announce" do
      before_each do
        Relationship::Content::Outbox.new(
          owner: actor,
          activity: create
        ).save
        Relationship::Content::Outbox.new(
          owner: actor,
          activity: announce
        ).save
      end

      it "renders the object's create aspect" do
        get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article/@class")).to contain_exactly("event activity-create")
      end
    end

    context "given a create, and an announce outside of actor's mailbox" do
      before_each do
        announce.save
        Relationship::Content::Outbox.new(
          owner: actor,
          activity: create
        ).save
      end

      it "renders the object's create aspect" do
        get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article/@class")).to contain_exactly("event activity-create")
      end
    end

    context "given an announce, and a create outside of actor's mailbox" do
      before_each do
        create.save
        Relationship::Content::Outbox.new(
          owner: actor,
          activity: announce
        ).save
      end

      it "renders the object's announce aspect" do
        get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article/@class")).to contain_exactly("event activity-announce")
      end
    end

    it "renders the collection" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//article")).to be_empty
    end

    it "renders the collection" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
    end
  end

  describe "GET /actors/:username/timeline" do
    it "returns 401 if not authorized" do
      get "/actors/missing/timeline", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/timeline", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/timeline", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/timeline", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 403 if different account" do
        get "/actors/#{register.actor.username}/timeline", ACCEPT_HTML
        expect(response.status_code).to eq(403)
      end

      it "returns 403 if different account" do
        get "/actors/#{register.actor.username}/timeline", ACCEPT_JSON
        expect(response.status_code).to eq(403)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/timeline", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/timeline", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      let(object) do
        ActivityPub::Object.new(
          iri: "https://remote/objects/#{random_string}",
          attributed_to: actor
        )
      end
      let!(timeline) do
        Relationship::Content::Timeline.new(
          owner: actor,
          object: object
        ).save
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/timeline", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article/@id").map(&.text)).to contain_exactly("object-#{object.id}")
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/timeline", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a.map(&.as_s)).to contain_exactly(object.iri)
      end
    end
  end

  describe "GET /actors/:username/notifications" do
    it "returns 401 if not authorized" do
      get "/actors/missing/notifications", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/notifications", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/notifications", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/notifications", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 403 if different account" do
        get "/actors/#{register.actor.username}/notifications", ACCEPT_HTML
        expect(response.status_code).to eq(403)
      end

      it "returns 403 if different account" do
        get "/actors/#{register.actor.username}/notifications", ACCEPT_JSON
        expect(response.status_code).to eq(403)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/notifications", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/notifications", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      let(activity) do
        ActivityPub::Activity.new(
          iri: "https://remote/activities/#{random_string}",
          actor_iri: actor.iri
        )
      end
      let!(notification) do
        Relationship::Content::Notification.new(
          owner: actor,
          activity: activity
        ).save
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/notifications", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//article//a/@href").map(&.text)).to contain_exactly(activity.iri)
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/notifications", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(activity.iri)
      end
    end
  end

  describe "GET /remote/actors/:id" do
    let!(actor) do
      ActivityPub::Actor.new(
        iri: "https://remote/#{random_string}"
      ).save
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/remote/actors/0", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/remote/actors/0", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if not found" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/actors/999999", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/actors/999999", headers
        expect(response.status_code).to eq(404)
      end

      it "renders the actor" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/actors/#{actor.id}", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
      end

      it "renders the actor" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/actors/#{actor.id}", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("id")).to be_truthy
      end
    end
  end

  describe "POST /remote/actors/:id/refresh" do
    let!(actor) do
      ActivityPub::Actor.new(
        iri: "https://remote/#{random_string}"
      ).save
    end

    it "returns 401 if not authorized" do
      post "/remote/actors/0/refresh"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if not found" do
        post "/remote/actors/999999/refresh"
        expect(response.status_code).to eq(404)
      end

      it "schedules the refresh task" do
        expect{post "/remote/actors/#{actor.id}/refresh"}.
          to change{Task::RefreshActor.exists?(actor.iri)}
      end
    end
  end
end
