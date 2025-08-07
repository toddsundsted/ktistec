require "../../src/controllers/oauth2"
require "../../src/models/oauth2/provider/client"
require "../../src/models/oauth2/provider/access_token"
require "../../src/models/account"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe OAuth2Controller do
  setup_spec

  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json"}
  HTML_HEADERS = HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"}

  describe "POST /oauth/register" do
    let(body) do
      {
        "redirect_uris" => "https://client.example.com/callback",
        "client_name" => "Test Client"
      }
    end

    it "registers a new client" do
      post "/oauth/register", headers: JSON_HEADERS, body: body.to_json

      expect(response.status_code).to eq(201)
      json_body = JSON.parse(response.body)
      expect(json_body["client_id"]?).not_to be_nil
      expect(json_body["client_secret"]?).not_to be_nil
    end

    context "with invalid metadata" do
      it "rejects a missing client_name" do
        body.delete("client_name")
        post "/oauth/register", headers: JSON_HEADERS, body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects a blank client_name" do
        body["client_name"] = "    "
        post "/oauth/register", headers: JSON_HEADERS, body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects a missing redirect_uris" do
        body.delete("redirect_uris")
        post "/oauth/register", headers: JSON_HEADERS, body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects an invalid redirect_uri" do
        body["redirect_uris"] = "not a valid uri"
        post "/oauth/register", headers: JSON_HEADERS, body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "rejects a redirect_uri that does not use https" do
        body["redirect_uris"] = "http://client.example.com/callback"
        post "/oauth/register", headers: JSON_HEADERS, body: body.to_json
        expect(response.status_code).to eq(400)
      end

      it "accepts a redirect_uris to localhost" do
        body["redirect_uris"] = "http://localhost:4000/callback"
        post "/oauth/register", headers: JSON_HEADERS, body: body.to_json
        expect(response.status_code).to eq(201)
      end
    end

    it "rejects malformed JSON" do
      post "/oauth/register", headers: JSON_HEADERS, body: "{\"client_name\": \"Test Client\", "
      expect(response.status_code).to eq(400)
    end

    context "when the provisional client buffer is full" do
      before_each do
        # set a small buffer size for testing
        OAuth2Controller.provisional_client_buffer_size = 2
        OAuth2Controller.provisional_clients.clear
      end

      it "discards the oldest client" do
        post "/oauth/register", body: {"client_name" => "Client 1", "redirect_uris" => "https://a.com"}.to_json
        client1_id = JSON.parse(response.body)["client_id"].as_s

        post "/oauth/register", body: {"client_name" => "Client 2", "redirect_uris" => "https://b.com"}.to_json
        client2_id = JSON.parse(response.body)["client_id"].as_s

        post "/oauth/register", body: {"client_name" => "Client 3", "redirect_uris" => "https://c.com"}.to_json
        client3_id = JSON.parse(response.body)["client_id"].as_s

        provisional_clients = OAuth2Controller.provisional_clients
        client_ids = provisional_clients.map(&.client_id)

        expect(client_ids).not_to contain(client1_id)
        expect(client_ids).to contain(client2_id, client3_id)
      end
    end
  end

  describe "GET /oauth/authorize" do
    it "redirects to the login page" do
      get "/oauth/authorize", headers: HTML_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in

      let(state) { random_string }
      let(code_challenge) { random_string }
      let(query) { "client_id=#{client.client_id}&redirect_uri=#{client.redirect_uris}&response_type=code&state=#{state}&code_challenge=#{code_challenge}&code_challenge_method=S256" }

      it "renders the consent screen" do
        get "/oauth/authorize?#{query}", headers: HTML_HEADERS
        expect(response.status_code).to eq(200)
        expect(response.body).to contain(client.client_name)
        expect(response.body).to contain(state)
      end

      context "without a code_challenge" do
        let(query) { super.gsub(/&code_challenge=(.+?)&/, "&") }

        it "returns a bad request" do
          get "/oauth/authorize?#{query}", headers: HTML_HEADERS
          expect(response.status_code).to eq(400)
        end
      end

      context "with an invalid code_challenge_method" do
        let(query) { super.gsub("code_challenge_method=S256", "code_challenge_method=plain") }

        it "returns a bad request" do
          get "/oauth/authorize?#{query}", headers: HTML_HEADERS
          expect(response.status_code).to eq(400)
        end
      end

      context "with an invalid client_id" do
        let(query) { super.gsub("client_id=#{client.client_id}", "client_id=invalid") }

        it "returns a bad request" do
          get "/oauth/authorize?#{query}", headers: HTML_HEADERS
          expect(response.status_code).to eq(400)
        end
      end

      context "with an invalid redirect_uri" do
        let(query) { super.gsub("redirect_uri=#{client.redirect_uris}", "redirect_uri=invalid") }

        it "returns a bad request" do
          get "/oauth/authorize?#{query}", headers: HTML_HEADERS
          expect(response.status_code).to eq(400)
        end
      end

      context "without a response_type" do
        let(query) { super.gsub("response_type=code", "response_type=invalid") }

        it "returns a bad request" do
          get "/oauth/authorize?#{query}", headers: HTML_HEADERS
          expect(response.status_code).to eq(400)
        end
      end

      context "with a provisional client" do
        let(client) do
          OAuth2::Provider::Client.new(
            client_id: Random::Secure.urlsafe_base64,
            client_secret: Random::Secure.urlsafe_base64,
            redirect_uris: "https://example.com/callback",
            client_name: "Provisional Client",
            scope: "mcp"
          )
        end

        before_each { OAuth2Controller.provisional_clients.push(client) }

        # assert that the client is not persisted to the database before and after each test

        pre_condition { expect{client.reload!}.to raise_error(Ktistec::Model::NotFound) }
        post_condition { expect{client.reload!}.to raise_error(Ktistec::Model::NotFound) }

        it "renders the consent screen" do
          get "/oauth/authorize?#{query}", headers: HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(response.body).to contain(client.client_name)
        end
      end
    end
  end

  describe "POST /oauth/authorize" do
    it "fails with a 401" do
      post "/oauth/authorize", headers: HTML_HEADERS, body: ""
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in

      let(state) { random_string }
      let(code_challenge) { random_string }
      let(body) { "client_id=#{client.client_id}&redirect_uri=#{client.redirect_uris}&response_type=code&scope=mcp&state=#{state}&code_challenge=#{code_challenge}&code_challenge_method=S256" }

      it "redirects to the client with a code" do
        post "/oauth/authorize", headers: HTML_HEADERS, body: body
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to match(%r|code=[a-zA-Z0-9+/_-]+|)
        expect(response.headers["Location"]).to contain("state=#{state}")
      end

      context "without a code_challenge" do
        let(body) { super.gsub(/&code_challenge=(.+?)&/, "&") }

        it "returns a bad request" do
          post "/oauth/authorize", headers: HTML_HEADERS, body: body
          expect(response.status_code).to eq(400)
        end
      end

      context "with an invalid code_challenge_method" do
        let(body) { super.gsub("code_challenge_method=S256", "code_challenge_method=plain") }

        it "returns a bad request" do
          post "/oauth/authorize", headers: HTML_HEADERS, body: body
          expect(response.status_code).to eq(400)
        end
      end

      context "with an invalid client_id" do
        let(body) { super.gsub("client_id=#{client.client_id}", "client_id=invalid") }

        it "returns a bad request" do
          post "/oauth/authorize", headers: HTML_HEADERS, body: body
          expect(response.status_code).to eq(400)
        end
      end

      context "with an invalid redirect_uri" do
        let(body) { super.gsub("redirect_uri=#{client.redirect_uris}", "redirect_uri=invalid") }

        it "returns a bad request" do
          post "/oauth/authorize", headers: HTML_HEADERS, body: body
          expect(response.status_code).to eq(400)
        end
      end

      context "without a response_type" do
        let(body) { super.gsub("response_type=code", "response_type=invalid") }

        it "returns a bad request" do
          post "/oauth/authorize", headers: HTML_HEADERS, body: body
          expect(response.status_code).to eq(400)
        end
      end

      context "with a provisional client" do
        let(client) do
          OAuth2::Provider::Client.new(
            client_id: Random::Secure.urlsafe_base64,
            client_secret: Random::Secure.urlsafe_base64,
            redirect_uris: "https://example.com/callback",
            client_name: "Provisional Client",
            scope: "mcp"
          )
        end

        before_each { OAuth2Controller.provisional_clients.push(client) }

        it "promotes it to a permanent client" do
          post "/oauth/authorize", headers: HTML_HEADERS, body: body
          expect(OAuth2Controller.provisional_clients).not_to have(client)
          expect(client.reload!).to eq(client)
        end

        context "when denied" do
          let(body) { super + "&deny=1" }

          it "redirects to the client with an error" do
            post "/oauth/authorize", headers: HTML_HEADERS, body: body
            expect(response.status_code).to eq(302)
            expect(response.headers["Location"]).to contain("error=access_denied")
            expect(response.headers["Location"]).to contain("state=#{state}")
          end

          it "deletes and does not promote the provisional client" do
            post "/oauth/authorize", headers: HTML_HEADERS, body: body
            expect(OAuth2Controller.provisional_clients).not_to have(client)
            expect{client.reload!}.to raise_error(Ktistec::Model::NotFound)
          end
        end
      end
    end
  end

  let_create(oauth2_provider_client, named: client)

  describe "POST /oauth/token" do
    let(account) { register }

    let(code) { "test_code" }

    let(code_verifier) { "a_very_long_and_unguessable_string_for_pkce" }
    let(code_challenge) { Base64.urlsafe_encode(Digest::SHA256.digest(code_verifier), padding: false) }

    let_create(oauth2_provider_client, named: test_client)

    def make_authorization_code(client_id = test_client.client_id, redirect_uri = "https://example.com/callback", code_challenge = code_challenge, code_challenge_method = "S256", expires_at = Time.utc + 1.minute)
      OAuth2Controller::AuthorizationCode.new(
        account_id: account.id.not_nil!,
        client_id: client_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        expires_at: expires_at,
      )
    end

    let(auth_code) { make_authorization_code }

    let(body) { "grant_type=authorization_code&code=#{code}&client_id=#{auth_code.client_id}&client_secret=#{test_client.client_secret}&redirect_uri=#{auth_code.redirect_uri}&code_verifier=#{code_verifier}" }

    before_each { OAuth2Controller.authorization_codes[code] = auth_code }

    it "returns an access token" do
      expect { post "/oauth/token", headers: HTML_HEADERS, body: body }.to change { OAuth2::Provider::AccessToken.count }.by(1)
      expect(response.status_code).to eq(200)
      json_body = JSON.parse(response.body)
      expect(json_body["access_token"]?).not_to be_nil
      expect(json_body["token_type"]?).to eq("Bearer")
      expect(json_body["expires_in"]?).to eq(3600 * 24)
    end

    it "updates the client's last_accessed_at timestamp" do
      expect { post "/oauth/token", headers: HTML_HEADERS, body: body }.to change { test_client.reload!.last_accessed_at }.from(nil)
      expect(test_client.reload!.last_accessed_at).to be_close(Time.utc, delta: 1.second)
    end

    it "deletes the authorization code after use" do
      post "/oauth/token", headers: HTML_HEADERS, body: body
      expect(OAuth2Controller.authorization_codes.has_key?(code)).to be_false
    end

    context "with basic authentication" do
      let(credentials) { Base64.strict_encode("#{test_client.client_id}:#{test_client.client_secret}") }

      let(body) { super.gsub(/client_secret=#{test_client.client_secret}/, "client_secret=invalid").gsub("client_id=#{test_client.client_id}", "client_id=invalid") }

      let(headers) { HTML_HEADERS.dup.add("Authorization", "Basic #{credentials}") }

      it "returns an access token" do
        expect { post "/oauth/token", headers: headers, body: body }.to change { OAuth2::Provider::AccessToken.count }.by(1)
        expect(response.status_code).to eq(200)
        json_body = JSON.parse(response.body)
        expect(json_body["access_token"]?).not_to be_nil
        expect(json_body["token_type"]?).to eq("Bearer")
        expect(json_body["expires_in"]?).to eq(3600 * 24)
      end

      it "deletes the authorization code after use" do
        post "/oauth/token", headers: headers, body: body
        expect(OAuth2Controller.authorization_codes.has_key?(code)).to be_false
      end
    end

    it "returns an error with an invalid grant_type" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub("grant_type=authorization_code", "grant_type=invalid")
      expect(response.status_code).to eq(400)
    end

    it "returns an error without a code" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub("code=#{code}&", "")
      expect(response.status_code).to eq(400)
    end

    it "returns an error with an invalid code" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub("code=#{code}", "code=invalid")
      expect(response.status_code).to eq(400)
    end

    context "given an expired code" do
      let(auth_code) { make_authorization_code(expires_at: Time.utc - 1.minute) }

      it "returns an error" do
        post "/oauth/token", headers: HTML_HEADERS, body: body
        expect(response.status_code).to eq(400)
      end
    end

    it "returns an error with a mismatched client_id" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub("client_id=#{auth_code.client_id}", "client_id=invalid")
      expect(response.status_code).to eq(400)
    end

    it "returns an error with an invalid client_secret" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub(/client_secret=([^&]+)/, "client_secret=invalid")
      expect(response.status_code).to eq(401)
    end

    it "returns an error with a mismatched redirect_uri" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub("redirect_uri=#{auth_code.redirect_uri}", "redirect_uri=https://attacker.com")
      expect(response.status_code).to eq(400)
    end

    it "returns an error with an invalid code_verifier" do
      post "/oauth/token", headers: HTML_HEADERS, body: body.gsub("code_verifier=#{code_verifier}", "code_verifier=invalid")
      expect(response.status_code).to eq(400)
    end
  end
end
