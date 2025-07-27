require "../../../src/controllers/oauth2/registration"
require "../../../src/models/oauth2/provider/client"
require "../../spec_helper/controller"
require "../../spec_helper/factory"

Spectator.describe OAuth2::RegistrationController do
  setup_spec

  describe "POST /oauth/register" do
    let(body) do
      {
        "redirect_uris" => "https://client.example.com/callback",
        "client_name" => "Test Client"
      }
    end

    it "registers a new client" do
      post "/oauth/register",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: body.to_json

      expect(response.status_code).to eq(201)
      json_body = JSON.parse(response.body)
      expect(json_body["client_id"]?).not_to be_nil
      expect(json_body["client_secret"]?).not_to be_nil
    end

    context "with invalid metadata" do
      it "rejects a missing client_name" do
        body.delete("client_name")
        post "/oauth/register",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects a blank client_name" do
        body["client_name"] = "    "
        post "/oauth/register",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects a missing redirect_uris" do
        body.delete("redirect_uris")
        post "/oauth/register",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects an invalid redirect_uri" do
        body["redirect_uris"] = "not a valid uri"
        post "/oauth/register",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: body.to_json
        expect(response.status_code).to eq(400)
      end
    end

    it "rejects malformed JSON" do
      post "/oauth/register",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: "{\"client_name\": \"Test Client\", "
      expect(response.status_code).to eq(400)
    end

    context "when the provisional client buffer is full" do
      before_each do
        # set a small buffer size for testing
        OAuth2::RegistrationController.provisional_client_buffer_size = 2
        OAuth2::RegistrationController.provisional_clients.clear
      end

      it "discards the oldest client" do
        post "/oauth/register", body: {"client_name" => "Client 1", "redirect_uris" => "https://a.com"}.to_json
        client1_id = JSON.parse(response.body)["client_id"].as_s

        post "/oauth/register", body: {"client_name" => "Client 2", "redirect_uris" => "https://b.com"}.to_json
        client2_id = JSON.parse(response.body)["client_id"].as_s

        post "/oauth/register", body: {"client_name" => "Client 3", "redirect_uris" => "https://c.com"}.to_json
        client3_id = JSON.parse(response.body)["client_id"].as_s

        provisional_clients = OAuth2::RegistrationController.provisional_clients
        client_ids = provisional_clients.map(&.client_id)

        expect(client_ids).not_to contain(client1_id)
        expect(client_ids).to contain(client2_id, client3_id)
      end
    end
  end
end
