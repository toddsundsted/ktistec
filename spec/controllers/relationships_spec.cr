require "../../src/controllers/relationships"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe RelationshipsController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json"}

  describe "GET /actors/:username/:relationship" do
    let(actor) { register.actor }
    let(other1) { register.actor }
    let(other2) { register.actor }

    it "returns 404 if actor does not exist" do
      get "/actors/0/following", HTML_HEADERS
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if actor does not exist" do
      get "/actors/0/following", JSON_HEADERS
      expect(response.status_code).to eq(404)
    end

    it "returns 401 if relationship type is not supported" do
      get "/actors/#{actor.username}/foobar", HTML_HEADERS
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if relationship type is not supported" do
      get "/actors/#{actor.username}/foobar", JSON_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "when relationship is following" do
      let_create!(
        :follow_relationship, named: :relationship1,
        actor: actor,
        object: other1,
        confirmed: true,
        visible: true
      )
      let_create!(
        :follow_relationship, named: :relationship2,
        actor: actor,
        object: other2
      )
      let_create!(
        :follow_relationship, named: :relationship3,
        actor: other1,
        object: other2
      )

      context "when unauthorized" do
        it "renders only the related public actors" do
          get "/actors/#{actor.username}/following", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//@href")).to contain(other1.iri)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//@href")).not_to contain(other2.iri)
        end

        it "renders only the related public actors" do
          get "/actors/#{actor.username}/following", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain(other1.iri)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).not_to contain(other2.iri)
        end
      end

      context "when authorized" do
        sign_in(as: actor.username)

        it "renders all the related actors" do
          get "/actors/#{actor.username}/following", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//@href")).to contain(other1.iri, other2.iri)
        end

        it "renders all the related actors" do
          get "/actors/#{actor.username}/following", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain(other1.iri, other2.iri)
        end

        it "renders only the related public actors" do
          get "/actors/#{other1.username}/following", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//li[@class='actor']//a/@href")).to be_empty
        end

        it "renders only the related public actors" do
          get "/actors/#{other1.username}/following", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
        end
      end
    end

    context "when relationship is followers" do
      let_create!(
        :follow_relationship, named: :relationship1,
        actor: other1,
        object: actor,
        confirmed: true,
        visible: true
      )
      let_create!(
        :follow_relationship, named: :relationship2,
        actor: other2,
        object: actor
      )
      let_create!(
        :follow_relationship, named: :relationship3,
        actor: other1,
        object: other2
      )

      context "when unauthorized" do
        it "renders only the related public actors" do
          get "/actors/#{actor.username}/followers", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//@href")).to contain(other1.iri)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//@href")).not_to contain(other2.iri)
        end

        it "renders only the related public actors" do
          get "/actors/#{actor.username}/followers", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain(other1.iri)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).not_to contain(other2.iri)
        end
      end

      context "when authorized" do
        sign_in(as: actor.username)

        it "renders all the related actors" do
          get "/actors/#{actor.username}/followers", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//@href")).to contain(other1.iri, other2.iri)
        end

        it "renders all the related actors" do
          get "/actors/#{actor.username}/followers", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain(other1.iri, other2.iri)
        end

        it "renders only the related public actors" do
          get "/actors/#{other1.username}/followers", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//li[@class='actor']//a/@href")).to be_empty
        end

        it "renders only the related public actors" do
          get "/actors/#{other1.username}/followers", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
        end
      end
    end
  end
end
