{% if flag?(:with_mastodon_api) %}
  require "../../src/controllers/api"
  require "../../src/models/oauth2/provider/client"

  require "../spec_helper/controller"
  require "../spec_helper/factory"

  Spectator.describe APIController do
    setup_spec

    JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}
    FORM_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "application/json"}

    def bearer_headers(token)
      HTTP::Headers{"Authorization" => "Bearer #{token}", "Accept" => "application/json"}
    end

    let(account) { register }
    let_create(:oauth2_provider_client, named: :client)

    describe "OPTIONS /api/v1/apps" do
      it "returns 204" do
        options "/api/v1/apps"
        expect(response.status_code).to eq(204)
      end

      it "includes Access-Control-Allow-Origin header" do
        options "/api/v1/apps"
        expect(response.headers["Access-Control-Allow-Origin"]?).to eq("*")
      end

      it "includes Access-Control-Allow-Methods header" do
        options "/api/v1/apps"
        expect(response.headers["Access-Control-Allow-Methods"]?).to eq("POST, OPTIONS")
      end
    end

    describe "POST /api/v1/apps" do
      context "with JSON body" do
        let(body) do
          {
            "client_name"   => "Test App",
            "redirect_uris" => "https://example.com/callback",
            "scopes"        => "read write",
          }.to_json
        end

        it "succeeds" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(200)
        end

        it "includes client_id" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["client_id"]?).not_to be_nil
        end

        it "includes client_secret" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["client_secret"]?).not_to be_nil
        end

        it "includes name" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["name"]).to eq("Test App")
        end

        it "includes scopes" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["scopes"].as_a.map(&.as_s)).to eq(["read", "write"])
        end

        it "includes redirect_uris as array" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["redirect_uris"].as_a.map(&.as_s)).to eq(["https://example.com/callback"])
        end

        it "includes redirect_uri as string" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["redirect_uri"]).to eq("https://example.com/callback")
        end

        it "includes client_secret_expires_at" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["client_secret_expires_at"]).to eq(0)
        end

        it "includes vapid_key" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["vapid_key"]).to eq("")
        end
      end

      context "with form-encoded body" do
        let(body) { "client_name=Test+App&redirect_uris=https%3A%2F%2Fexample.com%2Fcallback&scopes=read+write" }

        it "succeeds" do
          post "/api/v1/apps", headers: FORM_HEADERS, body: body
          expect(response.status_code).to eq(200)
        end

        it "parses client_name" do
          post "/api/v1/apps", headers: FORM_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["name"]).to eq("Test App")
        end

        it "parses scopes" do
          post "/api/v1/apps", headers: FORM_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["scopes"].as_a.map(&.as_s)).to eq(["read", "write"])
        end
      end

      context "with multiple redirect_uris" do
        let(body) do
          {
            "client_name"   => "Test App",
            "redirect_uris" => ["https://example.com/callback", "https://example.com/oauth"],
            "scopes"        => "read",
          }.to_json
        end

        it "succeeds" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(200)
        end

        it "includes redirect_uris as array" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["redirect_uris"].as_a.map(&.as_s)).to eq(["https://example.com/callback", "https://example.com/oauth"])
        end

        it "includes redirect_uri as string" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["redirect_uri"]).to eq("https://example.com/callback\nhttps://example.com/oauth")
        end
      end

      context "with urn:ietf:wg:oauth:2.0:oob" do
        let(body) do
          {
            "client_name"   => "Test App",
            "redirect_uris" => "urn:ietf:wg:oauth:2.0:oob",
            "scopes"        => "read",
          }.to_json
        end

        it "succeeds" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(200)
        end
      end

      context "with missing client_name" do
        let(body) do
          {
            "redirect_uris" => "https://example.com/callback",
          }.to_json
        end

        it "returns 422" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(422)
        end

        it "returns error message" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["error"].as_s?).to contain("client_name")
        end
      end

      context "with blank client_name" do
        let(body) do
          {
            "client_name"   => "   ",
            "redirect_uris" => "https://example.com/callback",
          }.to_json
        end

        it "returns 422" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(422)
        end

        it "returns error message" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["error"].as_s?).to contain("client_name")
        end
      end

      context "with missing redirect_uris" do
        let(body) do
          {
            "client_name" => "Test App",
          }.to_json
        end

        it "returns 422" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(422)
        end

        it "returns error message" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["error"].as_s?).to contain("redirect_uris")
        end
      end

      context "with invalid redirect_uris" do
        let(body) do
          {
            "client_name"   => "Test App",
            "redirect_uris" => "invalid uri",
          }.to_json
        end

        it "returns 422" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(422)
        end

        it "returns error message" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["error"].as_s?).to contain("redirect_uris")
        end
      end

      context "with website" do
        let(body) do
          {
            "client_name"   => "Test App",
            "redirect_uris" => "https://example.com/callback",
            "website"       => "https://myapp.example.com",
          }.to_json
        end

        it "succeeds" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(200)
        end

        it "includes website" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          json = JSON.parse(response.body)
          expect(json["website"]).to eq("https://myapp.example.com")
        end
      end

      context "with malformed JSON" do
        let(body) { "{\"client_name\": \"Test\"" }

        it "returns 400" do
          post "/api/v1/apps", headers: JSON_HEADERS, body: body
          expect(response.status_code).to eq(400)
        end
      end
    end

    describe "GET /api/v1/instance" do
      before_each { API::V1::Serializers::Instance.clear_cache! }

      it "succeeds" do
        get "/api/v1/instance"
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/instance"
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "includes uri" do
        get "/api/v1/instance"
        json = JSON.parse(response.body)
        expect(json["uri"].as_s).to eq("test.test")
      end
    end

    describe "GET /api/v2/instance" do
      before_each { API::V2::Serializers::Instance.clear_cache! }

      it "succeeds" do
        get "/api/v2/instance"
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v2/instance"
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "includes domain" do
        get "/api/v2/instance"
        json = JSON.parse(response.body)
        expect(json["domain"].as_s).to eq("test.test")
      end
    end

    describe "GET /api/v1/accounts/verify_credentials" do
      let(actor) { account.actor }

      it "returns 401" do
        get "/api/v1/accounts/verify_credentials", headers: JSON_HEADERS
        expect(response.status_code).to eq(401)
      end

      context "with invalid token" do
        it "returns 401" do
          get "/api/v1/accounts/verify_credentials", headers: bearer_headers("invalid_token")
          expect(response.status_code).to eq(401)
        end
      end

      context "with expired token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account, expires_at: 1.day.ago)

        it "returns 401" do
          get "/api/v1/accounts/verify_credentials", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(401)
        end
      end

      context "with valid app token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client) # account is nil

        it "returns 401" do
          get "/api/v1/accounts/verify_credentials", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(401)
        end
      end

      context "with valid user token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/accounts/verify_credentials", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/accounts/verify_credentials", headers: bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "includes source.language" do
          get "/api/v1/accounts/verify_credentials", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.dig?("source", "language")).to eq("en")
        end
      end
    end

    describe "GET /api/v1/timelines/home" do
      let(actor) { account.actor }

      it "returns 401" do
        get "/api/v1/timelines/home", headers: JSON_HEADERS
        expect(response.status_code).to eq(401)
      end

      context "with valid user token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/timelines/home", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/timelines/home", headers: bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "returns empty array" do
          get "/api/v1/timelines/home", headers: bearer_headers(access_token.token)
          expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
        end

        context "with timeline items" do
          let_create(:actor, named: :other_actor, local: true)
          let_create(:object, named: :post, attributed_to: other_actor, published: Time.utc, visible: true)

          before_each do
            put_in_timeline(actor, post)
          end

          it "returns statuses" do
            get "/api/v1/timelines/home", headers: bearer_headers(access_token.token)
            json = JSON.parse(response.body)
            expect(json.as_a.size).to eq(1)
          end

          it "includes id" do
            get "/api/v1/timelines/home", headers: bearer_headers(access_token.token)
            json = JSON.parse(response.body)
            expect(json[0]["id"]).to eq(post.id.to_s)
          end

          it "includes account.id" do
            get "/api/v1/timelines/home", headers: bearer_headers(access_token.token)
            json = JSON.parse(response.body)
            expect(json[0]["account"]["id"]).to eq(other_actor.id.to_s)
          end
        end
      end
    end

    describe "GET /api/v1/statuses/:id" do
      let(actor) { account.actor }
      let_create(:actor, named: :other, local: true)
      let_create(:object, named: :status, attributed_to: other, published: Time.utc, visible: true)

      it "returns 401" do
        get "/api/v1/statuses/#{status.id}", headers: JSON_HEADERS
        expect(response.status_code).to eq(401)
      end

      context "with valid user token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/statuses/#{status.id}", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/statuses/#{status.id}", headers: bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "includes id" do
          get "/api/v1/statuses/#{status.id}", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["id"]).to eq(status.id.to_s)
        end

        it "includes account.id" do
          get "/api/v1/statuses/#{status.id}", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["account"]["id"]).to eq(other.id.to_s)
        end

        it "returns 404 for non-existent status" do
          get "/api/v1/statuses/999999", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(404)
        end
      end
    end

    describe "GET /api/v1/statuses/:id/context" do
      let(actor) { account.actor }
      let_create!(:actor, named: :other, local: true)
      let_create!(:object, named: :root, attributed_to: other, published: Time.utc, visible: true)
      let_create!(:object, named: :reply1, attributed_to: other, in_reply_to: root, published: Time.utc, visible: true)
      let_create!(:object, named: :reply2, attributed_to: other, in_reply_to: reply1, published: Time.utc, visible: true)

      it "returns 401" do
        get "/api/v1/statuses/#{reply1.id}/context", headers: JSON_HEADERS
        expect(response.status_code).to eq(401)
      end

      context "with valid user token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/statuses/#{reply1.id}/context", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/statuses/#{reply1.id}/context", headers: bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "returns ancestors" do
          get "/api/v1/statuses/#{reply1.id}/context", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          ancestor_ids = json["ancestors"].as_a.map(&.["id"].as_s)
          expect(ancestor_ids).to eq([root.id.to_s])
        end

        it "returns descendants" do
          get "/api/v1/statuses/#{reply1.id}/context", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          descendant_ids = json["descendants"].as_a.map(&.["id"].as_s)
          expect(descendant_ids).to eq([reply2.id.to_s])
        end

        it "returns 404 for non-existent status" do
          get "/api/v1/statuses/999999/context", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(404)
        end
      end
    end

    describe "GET /api/v1/instance/translation_languages" do
      it "succeeds" do
        get "/api/v1/instance/translation_languages"
        expect(response.status_code).to eq(200)
      end

      it "returns empty object" do
        get "/api/v1/instance/translation_languages"
        expect(JSON.parse(response.body)).to eq(JSON.parse("{}"))
      end
    end

    describe "GET /api/v1/filters" do
      it "returns 401" do
        get "/api/v1/filters"
        expect(response.status_code).to eq(401)
      end

      context "with valid user access token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/filters", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns empty array" do
          get "/api/v1/filters", headers: bearer_headers(access_token.token)
          expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
        end
      end
    end

    describe "GET /api/v2/filters" do
      it "returns 401" do
        get "/api/v2/filters"
        expect(response.status_code).to eq(401)
      end

      context "with valid user access token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v2/filters", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns empty array" do
          get "/api/v2/filters", headers: bearer_headers(access_token.token)
          expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
        end
      end
    end

    describe "GET /api/v1/markers" do
      it "returns 401" do
        get "/api/v1/markers"
        expect(response.status_code).to eq(401)
      end

      context "with valid user access token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/markers", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns empty object" do
          get "/api/v1/markers", headers: bearer_headers(access_token.token)
          expect(JSON.parse(response.body)).to eq(JSON.parse("{}"))
        end
      end
    end

    describe "GET /api/v2/notifications/policy" do
      it "returns 401" do
        get "/api/v2/notifications/policy"
        expect(response.status_code).to eq(401)
      end

      context "with valid user access token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v2/notifications/policy", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns for_not_followers" do
          get "/api/v2/notifications/policy", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["for_not_followers"]).to eq("accept")
        end

        it "returns for_not_following" do
          get "/api/v2/notifications/policy", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["for_not_following"]).to eq("accept")
        end

        it "returns summary with pending counts" do
          get "/api/v2/notifications/policy", headers: bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.dig("summary", "pending_requests_count")).to eq(0)
          expect(json.dig("summary", "pending_notifications_count")).to eq(0)
        end
      end
    end

    describe "GET /api/v1/notifications" do
      it "returns 401" do
        get "/api/v1/notifications"
        expect(response.status_code).to eq(401)
      end

      context "with valid user access token" do
        let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

        it "succeeds" do
          get "/api/v1/notifications", headers: bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns empty array" do
          get "/api/v1/notifications", headers: bearer_headers(access_token.token)
          expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
        end
      end
    end
  end
{% end %}
