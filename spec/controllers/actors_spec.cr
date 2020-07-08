require "../spec_helper"

Spectator.describe ActorsController do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  describe "GET /actors/:username" do
    let(username) { random_string }
    let(password) { random_string }

    let!(account) { register(username, password) }

    it "returns 404 if not found" do
      get "/actors/missing"
      expect(response.status_code).to eq(404)
    end

    it "returns 200 if found" do
      get "/actors/#{username}"
      expect(response.status_code).to eq(200)
    end

    it "responds with HTML" do
      get "/actors/#{username}", HTTP::Headers{"Accept" => "text/html"}
      expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
    end

    it "responds with JSON, by default" do
      get "/actors/#{username}"
      expect(JSON.parse(response.body).dig("type")).to be_truthy
    end
  end

  describe "GET /remote/actors/:id" do
    let!(actor) do
      ActivityPub::Actor.new(
        iri: "https://external/#{random_string}"
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
end
