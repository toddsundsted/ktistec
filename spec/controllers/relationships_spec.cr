require "../spec_helper"

Spectator.describe RelationshipsController do
  setup_spec

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
        expect(XML.parse_html(response.body).xpath_nodes("//a[contains(@class,'card')]/@href").map(&.text)).to eq([other1.iri])
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
        expect(XML.parse_html(response.body).xpath_nodes("//a[contains(@class,'card')]/@href").map(&.text)).to contain_exactly(other1.iri, other2.iri)
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
end
