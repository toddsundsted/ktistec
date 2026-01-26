require "../../../src/controllers/admin/oauth_clients"

require "../../spec_helper/controller"
require "../../spec_helper/factory"

Spectator.describe Admin::OAuthClientsController do
  setup_spec

  let(account) { register }

  let(headers) { HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"} }

  let_create!(oauth2_provider_client, named: test_client, client_name: "Test Client")

  describe "GET /admin/oauth/clients" do
    it "returns 401 if not authorized" do
      get "/admin/oauth/clients"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "succeeds" do
        get "/admin/oauth/clients", headers
        expect(response.status_code).to eq(200)
      end

      it "renders client in a table" do
        get "/admin/oauth/clients", headers
        expect(XML.parse_html(response.body).xpath_nodes("//table//td[contains(text(), 'Test Client')]")).not_to be_empty
      end
    end
  end

  describe "POST /admin/oauth/clients" do
    it "returns 401 if not authorized" do
      post "/admin/oauth/clients", headers, "client_name=Test+App"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "creates a new OAuth client" do
        expect { post "/admin/oauth/clients", headers, "client_name=Test+App&redirect_uris=https%3A%2F%2Fexample.com%2Fcallback" }.to change { OAuth2::Provider::Client.count }.by(1)
        expect(response.status_code).to eq(302)
        client = OAuth2::Provider::Client.all.last
        expect(client.client_name).to eq("Test App")
        expect(client.redirect_uris).to eq("https://example.com/callback")
        expect(client.manual).to be_true
      end

      it "returns validation errors for blank client name" do
        expect { post "/admin/oauth/clients", headers, "client_name=&redirect_uris=https%3A%2F%2Fexample.com%2Fcallback" }.not_to change { OAuth2::Provider::Client.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("client_name must be present")
      end

      it "returns validation errors for blank redirect URIs" do
        expect { post "/admin/oauth/clients", headers, "client_name=Test+App&redirect_uris=" }.not_to change { OAuth2::Provider::Client.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("redirect_uris must be present")
      end

      it "returns validation errors for invalid redirect URIs" do
        expect { post "/admin/oauth/clients", headers, "client_name=Test+App&redirect_uris=invalid_uris" }.not_to change { OAuth2::Provider::Client.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("invalid URIs")
      end
    end
  end

  describe "DELETE /admin/oauth/clients/:id" do
    it "returns 401 if not authorized" do
      delete "/admin/oauth/clients/#{test_client.id}"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "deletes the OAuth client" do
        client_id = test_client.id
        expect { delete "/admin/oauth/clients/#{client_id}" }.to change { OAuth2::Provider::Client.count }.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/admin/oauth/clients")
      end

      context "with associated access token" do
        let_create!(oauth2_provider_access_token, client: test_client, account: account)

        it "deletes associated access token" do
          token_id = oauth2_provider_access_token.id
          expect { delete "/admin/oauth/clients/#{test_client.id}" }.to change { OAuth2::Provider::AccessToken.count }.by(-1)
          expect(response.status_code).to eq(302)
          expect(OAuth2::Provider::AccessToken.find?(token_id)).to be_nil
        end
      end

      it "returns 404 for non-existent client" do
        delete "/admin/oauth/clients/99999"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
