require "../../../src/controllers/admin/oauth_tokens"

require "../../spec_helper/controller"
require "../../spec_helper/factory"

Spectator.describe Admin::OAuthTokensController do
  setup_spec

  let(account) { register }

  let(headers) { HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"} }

  let_create!(oauth2_provider_client, named: test_client, client_name: "Test Client")
  let_create!(oauth2_provider_access_token, named: test_token, client: test_client, account: account, token: "test_token_123", expires_at: Time.utc + 1.hour)

  describe "GET /admin/oauth/tokens" do
    it "returns 401 if not authorized" do
      get "/admin/oauth/tokens"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "succeeds" do
        get "/admin/oauth/tokens", headers
        expect(response.status_code).to eq(200)
      end

      it "renders token in a table" do
        get "/admin/oauth/tokens", headers
        expect(XML.parse_html(response.body).xpath_nodes("//table//td[contains(text(), '#{account.username}')]")).not_to be_empty
      end
    end
  end

  describe "DELETE /admin/oauth/tokens/:id" do
    it "returns 401 if not authorized" do
      delete "/admin/oauth/tokens/#{test_token.id}"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "deletes the OAuth token" do
        token_id = test_token.id
        expect{delete "/admin/oauth/tokens/#{token_id}"}.to change{OAuth2::Provider::AccessToken.count}.by(-1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/admin/oauth/tokens")
      end

      it "returns 404 for non-existent token" do
        delete "/admin/oauth/tokens/99999"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
