require "../../src/controllers/proxy"

require "../spec_helper/factory"
require "../spec_helper/controller"
require "../spec_helper/network"

Spectator.describe ProxyController do
  setup_spec

  FORM_DATA = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}
  JSON_DATA = HTTP::Headers{"Content-Type" => "application/json"}

  let_build(:object)

  before_each do
    HTTP::Client.objects << object
  end

  describe "POST /proxy" do
    it "returns 401" do
      post "/proxy", FORM_DATA, "id=https://remote/objects/123"
      expect(response.status_code).to eq(401)
    end

    it "returns 401" do
      post "/proxy", JSON_DATA, %Q|{"id":"https://remote/objects/123"}|
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in

      it "validates object IRI" do
        post "/proxy", FORM_DATA, ""
        expect(response.status_code).to eq(400)
      end

      it "validates object IRI" do
        post "/proxy", JSON_DATA, "{}"
        expect(response.status_code).to eq(400)
      end

      it "fetches remote object" do
        post "/proxy", FORM_DATA, "id=#{object.iri}"
        expect(response.status_code).to eq(200)

        json = JSON.parse(response.body)
        expect(json["id"]).to eq(object.iri)
        expect(json["type"]).to eq("Object")
      end

      it "fetches remote object" do
        post "/proxy", JSON_DATA, %Q|{"id":"#{object.iri}"}|
        expect(response.status_code).to eq(200)

        json = JSON.parse(response.body)
        expect(json["id"]).to eq(object.iri)
        expect(json["type"]).to eq("Object")
      end
    end
  end
end
