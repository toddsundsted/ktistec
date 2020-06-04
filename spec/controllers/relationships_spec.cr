require "../spec_helper"

Spectator.describe RelationshipsController do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  describe "GET /actors/:username/:relationship" do
    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/actors/0/following", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/actors/0/following", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      let(actor) do
        ActivityPub::Actor.find(Global.account.not_nil!.iri)
      end
      let(other) do
        ActivityPub::Actor.new(iri: "https://unknown/#{random_string}").save
      end
      let(relationship) do
        Relationship::Social::Follow.new(
          from_iri: actor.iri,
          to_iri: other.iri
        ).save
      end

      sign_in

      it "renders the related actors" do
        relationship
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//li[@class='actor']//a/@href").first.text).to eq("/remote/actors/#{other.id}")
      end

      it "renders the related actors" do
        relationship
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/following", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("items", 0)).to eq("/remote/actors/#{other.id}")
      end

      it "returns 404 if not the current account" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{other.username}/following", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not the current account" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{other.username}/following", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if relationship type is not supported" do
        relationship
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/actors/#{actor.username}/foobar", headers
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if relationship type is not supported" do
        relationship
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/actors/#{actor.username}/foobar", headers
        expect(response.status_code).to eq(400)
      end
    end
  end

  describe "POST /actors/:username/:relationship" do
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
      let(actor) do
        ActivityPub::Actor.find(Global.account.not_nil!.iri)
      end
      let(other) do
        ActivityPub::Actor.new(iri: "https://unknown/#{random_string}").save
      end

      sign_in

      it "creates a relationship and redirects" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        expect{post "/actors/#{actor.username}/following", headers, "iri=#{other.iri}"}.to change{Relationship.count}.by(1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "creates a relationship and redirects" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        expect{post "/actors/#{actor.username}/following", headers, {iri: other.iri}.to_json}.to change{Relationship.count}.by(1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "returns 404 if not the current account" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{other.username}/following", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not the current account" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{other.username}/following", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if relationship type is not supported" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{actor.username}/foobar", headers, "iri=#{other.iri}"
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if relationship type is not supported" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/foobar", headers, {iri: other.iri}.to_json
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if other does not exist" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/actors/#{actor.username}/following", headers, "iri=foobar"
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if other does not exist" do
        actor && other
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/actors/#{actor.username}/following", headers, {iri: "foobar"}.to_json
        expect(response.status_code).to eq(400)
      end
    end
  end

  describe "DELETE /actors/:username/:relationship/:id" do
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
      let(actor) do
        ActivityPub::Actor.find(Global.account.not_nil!.iri)
      end
      let(other) do
        ActivityPub::Actor.new(iri: "https://unknown/#{random_string}").save
      end
      let(relationship) do
        Relationship::Social::Follow.new(
          from_iri: actor.iri,
          to_iri: other.iri
        ).save
      end

      sign_in

      it "deletes the relationship and redirects" do
        relationship
        headers = HTTP::Headers{"Accept" => "text/html"}
        expect{delete "/actors/#{actor.username}/following/#{relationship.id}", headers}.to change{Relationship.count}.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "deletes the relationship and redirects" do
        relationship
        headers = HTTP::Headers{"Accept" => "application/json"}
        expect{delete "/actors/#{actor.username}/following/#{relationship.id}", headers}.to change{Relationship.count}.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/following")
      end

      it "returns 404 if not the current account" do
        relationship
        headers = HTTP::Headers{"Accept" => "text/html"}
        delete "/actors/#{other.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not the current account" do
        relationship
        headers = HTTP::Headers{"Accept" => "application/json"}
        delete "/actors/#{other.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if relationship type is not supported" do
        relationship
        headers = HTTP::Headers{"Accept" => "text/html"}
        delete "/actors/#{actor.username}/foobar/#{relationship.id}", headers
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if relationship type is not supported" do
        relationship
        headers = HTTP::Headers{"Accept" => "application/json"}
        delete "/actors/#{actor.username}/foobar/#{relationship.id}", headers
        expect(response.status_code).to eq(400)
      end

      it "returns 404 if relationship does not belong to current account" do
        relationship = Relationship::Social::Follow.new(from_iri: other.iri, to_iri: other.iri).save
        headers = HTTP::Headers{"Accept" => "text/html"}
        delete "/actors/#{actor.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if relationship does not belong to current account" do
        relationship = Relationship::Social::Follow.new(from_iri: other.iri, to_iri: other.iri).save
        headers = HTTP::Headers{"Accept" => "application/json"}
        delete "/actors/#{actor.username}/following/#{relationship.id}", headers
        expect(response.status_code).to eq(404)
      end
    end
  end
end
