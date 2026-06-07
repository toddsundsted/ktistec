require "../../src/controllers/internal"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe InternalController do
  setup_spec

  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(account) { register }

  describe "GET /_internal/authenticated" do
    it "returns 401" do
      get "/_internal/authenticated", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "with an anonymous session" do
      let!(session) { Session.new.save }

      let(headers) do
        HTTP::Headers{
          "Accept" => "application/json",
          "Cookie" => "__Host-AuthToken=#{session.generate_jwt}",
        }
      end

      it "returns 401" do
        get "/_internal/authenticated", headers
        expect(response.status_code).to eq(401)
      end

      it "does not set redirect cookie" do
        get "/_internal/authenticated", headers
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
      end
    end

    context "when authorized via session cookie" do
      sign_in(as: account.username)

      it "returns 204" do
        get "/_internal/authenticated", ACCEPT_JSON
        expect(response.status_code).to eq(204)
      end

      it "returns an empty body" do
        get "/_internal/authenticated", ACCEPT_JSON
        expect(response.body).to be_blank
      end
    end

    context "when authorized via bearer token" do
      let_create(:oauth2_provider_client, named: :client)
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      let(headers) do
        HTTP::Headers{
          "Accept"        => "application/json",
          "Authorization" => "Bearer #{access_token.token}",
        }
      end

      it "returns 204" do
        get "/_internal/authenticated", headers
        expect(response.status_code).to eq(204)
      end

      it "returns an empty body" do
        get "/_internal/authenticated", headers
        expect(response.body).to be_blank
      end
    end

    context "with a bearer token not bound to an account" do
      let_create(:oauth2_provider_client, named: :client)
      let_create(:oauth2_provider_access_token, named: :access_token, client: client) # account is nil

      let(headers) do
        HTTP::Headers{
          "Accept"        => "application/json",
          "Authorization" => "Bearer #{access_token.token}",
        }
      end

      it "returns 401" do
        get "/_internal/authenticated", headers
        expect(response.status_code).to eq(401)
      end

      it "does not set redirect cookie" do
        get "/_internal/authenticated", headers
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
      end
    end
  end
end
