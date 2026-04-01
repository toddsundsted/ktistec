require "../../src/controllers/api"
require "../../src/models/oauth2/provider/client"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe APIController do
  setup_spec

  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}
  FORM_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "application/json"}

  def json_bearer_headers(token)
    JSON_HEADERS.clone.tap { |h| h["Authorization"] = "Bearer #{token}" }
  end

  def form_bearer_headers(token)
    FORM_HEADERS.clone.tap { |h| h["Authorization"] = "Bearer #{token}" }
  end

  let(account) { register }
  let_create(:oauth2_provider_client, named: :client)

  describe "OPTIONS /api/*" do
    it "returns 204" do
      options "/api/v1/instance"
      expect(response.status_code).to eq(204)
    end

    it "returns 204" do
      options "/api/v2/instance"
      expect(response.status_code).to eq(204)
    end

    it "includes Access-Control-Allow-Origin header" do
      options "/api/v1/apps"
      expect(response.headers["Access-Control-Allow-Origin"]?).to eq("*")
    end

    it "includes Access-Control-Allow-Methods header" do
      options "/api/v1/apps"
      expect(response.headers["Access-Control-Allow-Methods"]?).to eq("GET, POST, PUT, PATCH, DELETE, OPTIONS")
    end

    it "includes Access-Control-Allow-Headers header" do
      options "/api/v1/apps"
      expect(response.headers["Access-Control-Allow-Headers"]?).to eq("Authorization, Content-Type")
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
        get "/api/v1/accounts/verify_credentials", headers: json_bearer_headers("invalid_token")
        expect(response.status_code).to eq(401)
      end
    end

    context "with expired token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account, expires_at: 1.day.ago)

      it "returns 401" do
        get "/api/v1/accounts/verify_credentials", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(401)
      end
    end

    context "with valid app token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client) # account is nil

      it "returns 401" do
        get "/api/v1/accounts/verify_credentials", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(401)
      end
    end

    context "with valid user token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/accounts/verify_credentials", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/accounts/verify_credentials", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "includes source.language" do
        get "/api/v1/accounts/verify_credentials", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.dig?("source", "language")).to eq("en")
      end
    end
  end

  describe "GET /api/v1/accounts" do
    it "returns 401" do
      get "/api/v1/accounts"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)
      let_create(:actor, named: :local, local: true)
      let_create(:actor, named: :remote)

      it "succeeds" do
        get "/api/v1/accounts", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v1/accounts", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a).to be_empty
      end

      it "returns multiple accounts" do
        get "/api/v1/accounts?id%5B%5D=#{local.id}&id%5B%5D=#{remote.id}", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a.size).to eq(2)
      end

      it "returns the actors's ids" do
        get "/api/v1/accounts?id%5B%5D=#{local.id}&id%5B%5D=#{remote.id}", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a.map(&.dig?("id"))).to eq([local.id.to_s, remote.id.to_s])
      end

      it "skips unknown ids" do
        get "/api/v1/accounts?id%5B%5D=#{local.id}&id%5B%5D=999999", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a.size).to eq(1)
      end

      it "skips bad ids" do
        get "/api/v1/accounts?id%5B%5D=#{local.id}&id%5B%5D=abc", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a.size).to eq(1)
      end
    end
  end

  describe "GET /api/v1/accounts/lookup" do
    it "returns 401" do
      get "/api/v1/accounts/lookup?acct=nobody@nowhere"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "returns 404" do
        get "/api/v1/accounts/lookup", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      it "returns 404" do
        get "/api/v1/accounts/lookup?acct=nobody@nowhere", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      it "returns 404" do
        get "/api/v1/accounts/lookup?acct=user@host@host", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      context "given an existing actor" do
        let_create!(:actor, username: "foobar")

        it "succeeds" do
          get "/api/v1/accounts/lookup?acct=foobar@remote", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns the actor's id" do
          get "/api/v1/accounts/lookup?acct=foobar@remote", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["id"]).to eq(actor.id.to_s)
        end
      end
    end
  end

  describe "GET /api/v1/accounts/:id" do
    let_create(:actor)

    it "returns 401" do
      get "/api/v1/accounts/#{actor.id}"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "returns 404" do
        get "/api/v1/accounts/999999", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      context "with a local actor" do
        let(local_actor) { register.actor }

        it "succeeds" do
          get "/api/v1/accounts/#{local_actor.id}", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns the actor's id" do
          get "/api/v1/accounts/#{local_actor.id}", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["id"]).to eq(local_actor.id.to_s)
        end

        it "returns locked" do
          get "/api/v1/accounts/#{local_actor.id}", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["locked"]).to eq(true)
        end
      end

      context "with a remote actor" do
        before_each { actor.assign(username: "remote").save }

        it "succeeds" do
          get "/api/v1/accounts/#{actor.id}", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns the actor's id" do
          get "/api/v1/accounts/#{actor.id}", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["id"]).to eq(actor.id.to_s)
        end

        it "returns locked" do
          get "/api/v1/accounts/#{actor.id}", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["locked"]).to eq(false)
        end
      end
    end
  end

  describe "GET /api/v1/accounts/:id/statuses" do
    macro published_post(index, actor, visible = true)
      let_create(:object, named: post{{index}}, attributed_to: {{actor}}, visible: {{visible}}, local: true, published: Time.utc)
      let_create(:create, named: create{{index}}, actor: {{actor}}, object: post{{index}}, local: true)
    end

    it "returns 401" do
      get "/api/v1/accounts/0/statuses"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let(actor) { account.actor }
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/accounts/#{actor.id}/statuses", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/accounts/#{actor.id}/statuses", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "returns empty array" do
        get "/api/v1/accounts/#{actor.id}/statuses", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body).as_a).to be_empty
      end

      it "returns 404" do
        get "/api/v1/accounts/999999/statuses", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      context "with your posts" do
        published_post(1, actor)
        published_post(2, actor)
        published_post(3, actor, visible: false)

        before_each do
          put_in_outbox(actor, create1)
          put_in_outbox(actor, create2)
          put_in_outbox(actor, create3)
        end

        it "returns all statuses" do
          get "/api/v1/accounts/#{actor.id}/statuses", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.size).to eq(3)
        end

        it "returns status ids" do
          get "/api/v1/accounts/#{actor.id}/statuses", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).to contain_exactly(post1.id.to_s, post2.id.to_s, post3.id.to_s).in_any_order
        end

        it "includes link header" do
          get "/api/v1/accounts/#{actor.id}/statuses?limit=1", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="next"))
        end
      end

      context "viewing a local actor's posts" do
        let_create(:actor, named: :local_actor, local: true)
        published_post(4, local_actor)
        published_post(5, local_actor, visible: false)

        before_each do
          put_in_outbox(local_actor, create4)
          put_in_outbox(local_actor, create5)
        end

        it "returns public statuses" do
          get "/api/v1/accounts/#{local_actor.id}/statuses", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).to contain(post4.id.to_s)
        end

        it "excludes private statuses" do
          get "/api/v1/accounts/#{local_actor.id}/statuses", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).not_to contain(post5.id.to_s)
        end
      end

      context "viewing a remote actor's posts" do
        let_create(:actor, named: :remote_actor, local: false)
        let_create!(:object, named: :post6, attributed_to: remote_actor, visible: true, published: Time.utc)
        let_create!(:object, named: :post7, attributed_to: remote_actor, visible: false, published: Time.utc)

        it "returns public statuses" do
          get "/api/v1/accounts/#{remote_actor.id}/statuses", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).to contain(post6.id.to_s)
        end

        it "excludes private statuses" do
          get "/api/v1/accounts/#{remote_actor.id}/statuses", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).not_to contain(post7.id.to_s)
        end
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
        get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "returns empty array" do
        get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
      end

      it "does not include link header" do
        get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Link"]?).to be_nil
      end

      context "with timeline items" do
        let_create(:actor, named: :other, local: true)
        let_create(:object, named: :post1, attributed_to: other, published: Time.utc, visible: true)
        let_create(:object, named: :post2, attributed_to: other, published: Time.utc, visible: true)

        before_each do
          put_in_timeline(actor, post1)
          put_in_timeline(actor, post2)
        end

        it "returns statuses" do
          get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.size).to eq(2)
        end

        it "includes id" do
          get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig?("id"))).to eq([post2.id.to_s, post1.id.to_s])
        end

        it "includes account.id" do
          get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig?("account", "id"))).to eq([other.id.to_s, other.id.to_s])
        end

        it "includes prev" do
          get "/api/v1/timelines/home", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="prev"))
        end

        it "includes next" do
          get "/api/v1/timelines/home?limit=1", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="next"))
        end
      end
    end
  end

  describe "GET /api/v1/timelines/public" do
    it "returns 401" do
      get "/api/v1/timelines/public", headers: JSON_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "with valid user token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "returns empty array" do
        get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
      end

      it "does not include link header" do
        get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Link"]?).to be_nil
      end

      context "with posts" do
        let_create(:actor, named: :other, local: true)
        let_create!(:object, named: :post1, attributed_to: other, published: Time.utc, visible: true)
        let_create!(:object, named: :post2, attributed_to: other, published: Time.utc, visible: true)

        it "returns statuses" do
          get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.size).to eq(2)
        end

        it "includes id" do
          get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig?("id"))).to eq([post2.id.to_s, post1.id.to_s])
        end

        it "includes account.id" do
          get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig?("account", "id"))).to eq([other.id.to_s, other.id.to_s])
        end

        it "includes prev" do
          get "/api/v1/timelines/public", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="prev"))
        end

        it "includes next" do
          get "/api/v1/timelines/public?limit=1", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="next"))
        end

        it "accepts local parameter" do
          get "/api/v1/timelines/public?local=true", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "accepts remote parameter" do
          get "/api/v1/timelines/public?remote=true", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "accepts only_media parameter" do
          get "/api/v1/timelines/public?only_media=true", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
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
        get "/api/v1/statuses/#{status.id}", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/statuses/#{status.id}", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "includes id" do
        get "/api/v1/statuses/#{status.id}", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(status.id.to_s)
      end

      it "includes account.id" do
        get "/api/v1/statuses/#{status.id}", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["account"]["id"]).to eq(other.id.to_s)
      end

      it "returns 404 for non-existent status" do
        get "/api/v1/statuses/999999", headers: json_bearer_headers(access_token.token)
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
        get "/api/v1/statuses/#{reply1.id}/context", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        get "/api/v1/statuses/#{reply1.id}/context", headers: json_bearer_headers(access_token.token)
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "returns ancestors" do
        get "/api/v1/statuses/#{reply1.id}/context", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        ancestor_ids = json["ancestors"].as_a.map(&.["id"].as_s)
        expect(ancestor_ids).to eq([root.id.to_s])
      end

      it "returns descendants" do
        get "/api/v1/statuses/#{reply1.id}/context", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        descendant_ids = json["descendants"].as_a.map(&.["id"].as_s)
        expect(descendant_ids).to eq([reply2.id.to_s])
      end

      it "returns 404 for non-existent status" do
        get "/api/v1/statuses/999999/context", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /api/v1/statuses" do
    let(actor) { account.actor }

    it "returns 401" do
      post "/api/v1/statuses", headers: JSON_HEADERS, body: {"status" => "Hello"}.to_json
      expect(response.status_code).to eq(401)
    end

    context "with valid user token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello world"}.to_json
        expect(response.status_code).to eq(200)
      end

      it "returns JSON" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello world"}.to_json
        expect(response.headers["Content-Type"]?).to eq("application/json")
      end

      it "returns an id" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello world"}.to_json
        json = JSON.parse(response.body)
        expect(json["id"].as_s).not_to be_empty
      end

      it "returns the content" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello world"}.to_json
        json = JSON.parse(response.body)
        expect(json["content"].as_s).to contain("Hello world")
      end

      it "returns the account id" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello world"}.to_json
        json = JSON.parse(response.body)
        expect(json["account"]["id"].as_s).to eq(actor.id.to_s)
      end

      it "defaults visibility to public" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello"}.to_json
        json = JSON.parse(response.body)
        expect(json["visibility"].as_s).to eq("public")
      end

      it "sets visibility to public" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello", "visibility" => "public"}.to_json
        json = JSON.parse(response.body)
        expect(json["visibility"].as_s).to eq("public")
      end

      it "sets visibility to private" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello", "visibility" => "private"}.to_json
        json = JSON.parse(response.body)
        expect(json["visibility"].as_s).to eq("private")
      end

      it "sets visibility to direct" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello", "visibility" => "direct"}.to_json
        json = JSON.parse(response.body)
        expect(json["visibility"].as_s).to eq("direct")
      end

      it "treats unlisted as public" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello", "visibility" => "unlisted"}.to_json
        json = JSON.parse(response.body)
        expect(json["visibility"].as_s).to eq("public")
      end

      it "sets spoiler_text" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello", "spoiler_text" => "CW"}.to_json
        json = JSON.parse(response.body)
        expect(json["spoiler_text"].as_s).to eq("CW")
      end

      it "sets sensitive" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Hello", "sensitive" => true}.to_json
        json = JSON.parse(response.body)
        expect(json["sensitive"].as_bool).to be_true
      end

      it "sets language" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Bonjour", "language" => "fr"}.to_json
        json = JSON.parse(response.body)
        expect(json["language"].as_s).to eq("fr")
      end

      context "with in_reply_to_id" do
        let_create(:object, named: :parent, attributed_to: actor, published: Time.utc, visible: true)

        it "sets in_reply_to_id" do
          post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Reply", "in_reply_to_id" => parent.id.to_s}.to_json
          json = JSON.parse(response.body)
          expect(json["in_reply_to_id"].as_s).to eq(parent.id.to_s)
        end

        it "returns 422 for invalid in_reply_to_id" do
          post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => "Reply", "in_reply_to_id" => "999999"}.to_json
          expect(response.status_code).to eq(422)
        end
      end

      context "with form-encoded body" do
        it "succeeds" do
          post "/api/v1/statuses", headers: form_bearer_headers(access_token.token), body: "status=Hello+world"
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          post "/api/v1/statuses", headers: form_bearer_headers(access_token.token), body: "status=Hello+world"
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "returns an id" do
          post "/api/v1/statuses", headers: form_bearer_headers(access_token.token), body: "status=Hello+world"
          json = JSON.parse(response.body)
          expect(json["id"].as_s).not_to be_empty
        end

        it "returns the content" do
          post "/api/v1/statuses", headers: form_bearer_headers(access_token.token), body: "status=Hello+world"
          json = JSON.parse(response.body)
          expect(json["content"].as_s).to contain("Hello world")
        end

        it "sets visibility" do
          post "/api/v1/statuses", headers: form_bearer_headers(access_token.token), body: "status=Hello&visibility=private"
          json = JSON.parse(response.body)
          expect(json["visibility"].as_s).to eq("private")
        end
      end

      it "returns 422 when status is blank" do
        post "/api/v1/statuses", headers: json_bearer_headers(access_token.token), body: {"status" => ""}.to_json
        expect(response.status_code).to eq(422)
      end
    end
  end

  describe "POST /api/v1/statuses/:id/favourite" do
    let_create(:object, attributed_to: account.actor, published: Time.utc, visible: true)

    it "returns 401" do
      post "/api/v1/statuses/#{object.id}/favourite"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        post "/api/v1/statuses/#{object.id}/favourite", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns favourited as true" do
        post "/api/v1/statuses/#{object.id}/favourite", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["favourited"]).to eq(true)
      end

      it "returns 404" do
        post "/api/v1/statuses/999999/favourite", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /api/v1/statuses/:id/unfavourite" do
    let_create(:object, attributed_to: account.actor, published: Time.utc, visible: true)

    it "returns 401" do
      post "/api/v1/statuses/#{object.id}/unfavourite"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      context "when liked" do
        let_create!(:like, actor: account.actor, object: object)

        it "succeeds" do
          post "/api/v1/statuses/#{object.id}/unfavourite", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns favourited as false" do
          post "/api/v1/statuses/#{object.id}/unfavourite", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["favourited"]).to eq(false)
        end

        it "returns 404" do
          post "/api/v1/statuses/999999/unfavourite", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(404)
        end
      end
    end
  end

  describe "POST /api/v1/statuses/:id/reblog" do
    let_create(:object, attributed_to: account.actor, published: Time.utc, visible: true)

    it "returns 401" do
      post "/api/v1/statuses/#{object.id}/reblog"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        post "/api/v1/statuses/#{object.id}/reblog", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns reblogged as true" do
        post "/api/v1/statuses/#{object.id}/reblog", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["reblogged"]).to eq(true)
      end

      it "returns 404" do
        post "/api/v1/statuses/999999/reblog", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /api/v1/statuses/:id/unreblog" do
    let_create(:object, attributed_to: account.actor, published: Time.utc, visible: true)

    it "returns 401" do
      post "/api/v1/statuses/#{object.id}/unreblog"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      context "when announced" do
        let_create!(:announce, actor: account.actor, object: object)

        it "succeeds" do
          post "/api/v1/statuses/#{object.id}/unreblog", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns reblogged as false" do
          post "/api/v1/statuses/#{object.id}/unreblog", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["reblogged"]).to eq(false)
        end

        it "returns 404" do
          post "/api/v1/statuses/999999/unreblog", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(404)
        end
      end
    end
  end

  describe "POST /api/v1/statuses/:id/bookmark" do
    let_create(:object, attributed_to: account.actor, published: Time.utc, visible: true)

    it "returns 401" do
      post "/api/v1/statuses/#{object.id}/bookmark"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        post "/api/v1/statuses/#{object.id}/bookmark", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns bookmarked as true" do
        post "/api/v1/statuses/#{object.id}/bookmark", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["bookmarked"]).to eq(true)
      end

      it "returns 404" do
        post "/api/v1/statuses/999999/bookmark", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /api/v1/statuses/:id/unbookmark" do
    let_create(:object, attributed_to: account.actor, published: Time.utc, visible: true)

    it "returns 401" do
      post "/api/v1/statuses/#{object.id}/unbookmark"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      context "when bookmarked" do
        let_create!(:bookmark_relationship, actor: account.actor, object: object)

        it "succeeds" do
          post "/api/v1/statuses/#{object.id}/unbookmark", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns bookmarked as false" do
          post "/api/v1/statuses/#{object.id}/unbookmark", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["bookmarked"]).to eq(false)
        end

        it "returns 404" do
          post "/api/v1/statuses/999999/unbookmark", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(404)
        end
      end
    end
  end

  describe "GET /api/v1/preferences" do
    it "returns 401" do
      get "/api/v1/preferences"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/preferences", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns posting:default:visibility" do
        get "/api/v1/preferences", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["posting:default:visibility"]).to eq("public")
      end

      it "returns posting:default:sensitive" do
        get "/api/v1/preferences", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["posting:default:sensitive"]).to eq(false)
      end

      it "returns posting:default:language from account" do
        get "/api/v1/preferences", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["posting:default:language"]).to eq("en")
      end
    end
  end

  describe "GET /api/v1/accounts/relationships" do
    it "returns 401" do
      get "/api/v1/accounts/relationships"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)
      let_create(:actor, named: :other1, local: true)
      let_create(:actor, named: :other2, local: true)

      it "succeeds" do
        get "/api/v1/accounts/relationships?id%5B%5D=#{other1.id}", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "handles multiple ids" do
        get "/api/v1/accounts/relationships?id%5B%5D=#{other1.id}&id%5B%5D=#{other2.id}", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a.size).to eq(2)
      end

      it "returns the ids" do
        get "/api/v1/accounts/relationships?id%5B%5D=#{other1.id}&id%5B%5D=#{other2.id}", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a.map(&.dig?("id"))).to eq([other1.id.to_s, other2.id.to_s])
      end

      it "returns empty array" do
        get "/api/v1/accounts/relationships?id%5B%5D=999999", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json.as_a).to be_empty
      end
    end
  end

  describe "POST /api/v1/polls/:id/votes" do
    let_create!(:question, published: Time.utc)
    let_create!(:poll, question: question, options: [
      Poll::Option.new("Yes", 0),
      Poll::Option.new("No", 0),
    ])

    it "returns 401" do
      post "/api/v1/polls/#{poll.id}/votes"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        expect(response.status_code).to eq(200)
      end

      it "returns a poll" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(poll.id.to_s)
      end

      it "returns voted" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        json = JSON.parse(response.body)
        expect(json["voted"]).to eq(true)
      end

      it "returns own_votes" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        json = JSON.parse(response.body)
        expect(json["own_votes"]).to eq([0])
      end

      it "assigns published" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        expect(question.votes_by(account.actor).all?(&.published.is_a?(Time))).to be_true
      end

      it "assigns special" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        expect(question.votes_by(account.actor).all?(&.special.==("vote"))).to be_true
      end

      it "assigns to" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        expect(question.votes_by(account.actor).flat_map(&.to)).to contain_exactly(question.attributed_to.iri)
      end

      it "does not assign cc" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        expect(question.votes_by(account.actor).flat_map(&.cc)).to be_empty
      end

      it "schedules deliveries" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        question.votes_by(account.actor).each do |vote|
          create_activity = ActivityPub::Activity::Create.find(actor: account.actor, object: vote)
          expect(Task::Deliver.find?(sender: account.actor, activity: create_activity)).not_to be_nil
        end
      end

      context "when poll has future closed_at" do
        before_each { poll.assign(closed_at: 1.day.from_now).save }

        it "creates notification task" do
          expect { post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json }.to change { Task::NotifyPollExpiry.count }.by(1)
        end

        it "schedules task for poll closed_at time" do
          post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
          task = Task::NotifyPollExpiry.find(question: question)
          expect(task.next_attempt_at).to be_close(poll.closed_at.not_nil!, 1.second)
        end
      end

      context "when notification task already exists" do
        before_each { poll.assign(closed_at: 1.day.from_now).save }

        let_create!(:notify_poll_expiry_task, question: question)

        it "does not create another task" do
          expect { post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json }.not_to change { Task::NotifyPollExpiry.count }
        end
      end

      context "when poll has no closed_at" do
        before_each { poll.assign(closed_at: nil).save }

        it "does not create task" do
          expect { post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json }.not_to change { Task::NotifyPollExpiry.count }
        end
      end

      context "when poll has closed_at in the past" do
        before_each { poll.assign(closed_at: 1.day.ago).save }

        it "does not create task" do
          expect { post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json }.not_to change { Task::NotifyPollExpiry.count }
        end
      end

      it "returns 404" do
        post "/api/v1/polls/999999/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
        expect(response.status_code).to eq(404)
      end

      context "given an expired poll" do
        before_each { poll.assign(closed_at: 1.day.ago).save }

        it "returns 422" do
          post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
          expect(response.status_code).to eq(422)
        end
      end

      context "given an existing vote" do
        let_create!(:note, attributed_to: account.actor, in_reply_to: question, name: "Yes", special: "vote")

        it "returns 422" do
          post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
          expect(response.status_code).to eq(422)
        end
      end

      context "given the author's own poll" do
        before_each { question.assign(attributed_to: account.actor).save }

        it "returns 422" do
          post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0]}.to_json
          expect(response.status_code).to eq(422)
        end
      end

      context "given a multiple-choice poll" do
        before_each { poll.assign(multiple_choice: true).save }

        it "succeeds with multiple choices on multiple-choice poll" do
          post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0, 1]}.to_json
          expect(response.status_code).to eq(200)
        end
      end

      it "returns 422" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [0, 1]}.to_json
        expect(response.status_code).to eq(422)
      end

      it "returns 422" do
        post "/api/v1/polls/#{poll.id}/votes", headers: json_bearer_headers(access_token.token), body: {"choices" => [99]}.to_json
        expect(response.status_code).to eq(422)
      end

      context "with form-encoded body" do
        it "succeeds" do
          post "/api/v1/polls/#{poll.id}/votes", headers: form_bearer_headers(access_token.token), body: "choices[]=0"
          expect(response.status_code).to eq(200)
        end

        it "returns a poll" do
          post "/api/v1/polls/#{poll.id}/votes", headers: form_bearer_headers(access_token.token), body: "choices[]=0"
          json = JSON.parse(response.body)
          expect(json["id"]).to eq(poll.id.to_s)
        end
      end
    end
  end

  describe "GET /api/v1/accounts/:id/following" do
    it "returns 401" do
      get "/api/v1/accounts/0/following"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let(actor) { account.actor }
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "returns empty array" do
        get "/api/v1/accounts/#{actor.id}/following", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body).as_a).to be_empty
      end

      it "returns 404" do
        get "/api/v1/accounts/999999/following", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      context "with following" do
        let_create(:actor, named: :followed1)
        let_create(:actor, named: :followed2)
        let_create(:actor, named: :followed3)

        before_each do
          actor.follow(followed1, confirmed: true, visible: true).save
          actor.follow(followed2, confirmed: true, visible: true).save
          actor.follow(followed3, confirmed: true, visible: true).save
        end

        it "succeeds" do
          get "/api/v1/accounts/#{actor.id}/following", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/accounts/#{actor.id}/following", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "returns all following" do
          get "/api/v1/accounts/#{actor.id}/following", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.size).to eq(3)
        end

        it "returns account ids" do
          get "/api/v1/accounts/#{actor.id}/following", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).to contain(followed1.id.to_s, followed2.id.to_s, followed3.id.to_s)
        end

        it "includes link header" do
          get "/api/v1/accounts/#{actor.id}/following?limit=1", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="next"))
        end
      end
    end
  end

  describe "GET /api/v1/accounts/:id/followers" do
    it "returns 401" do
      get "/api/v1/accounts/0/followers"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let(actor) { account.actor }
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "returns empty array" do
        get "/api/v1/accounts/#{actor.id}/followers", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body).as_a).to be_empty
      end

      it "returns 404" do
        get "/api/v1/accounts/999999/followers", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      context "with followers" do
        let_create(:actor, named: :follower1)
        let_create(:actor, named: :follower2)
        let_create(:actor, named: :follower3)

        before_each do
          follower1.follow(actor, confirmed: true, visible: true).save
          follower2.follow(actor, confirmed: true, visible: true).save
          follower3.follow(actor, confirmed: true, visible: true).save
        end

        it "succeeds" do
          get "/api/v1/accounts/#{actor.id}/followers", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/accounts/#{actor.id}/followers", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "returns all followers" do
          get "/api/v1/accounts/#{actor.id}/followers", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.size).to eq(3)
        end

        it "returns account ids" do
          get "/api/v1/accounts/#{actor.id}/followers", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).to contain(follower1.id.to_s, follower2.id.to_s, follower3.id.to_s)
        end

        it "includes link header" do
          get "/api/v1/accounts/#{actor.id}/followers?limit=1", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="next"))
        end
      end
    end
  end

  describe "GET /api/v1/follow_requests" do
    it "returns 401" do
      get "/api/v1/follow_requests"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let(actor) { account.actor }
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "returns empty array" do
        get "/api/v1/follow_requests", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body).as_a).to be_empty
      end

      context "with pending follow requests" do
        let_create(:actor, named: :requester1)
        let_create(:actor, named: :requester2)
        let_create(:actor, named: :requester3)

        before_each do
          requester1.follow(actor, confirmed: false, visible: false).save
          requester2.follow(actor, confirmed: false, visible: false).save
          requester3.follow(actor, confirmed: false, visible: false).save
        end

        it "succeeds" do
          get "/api/v1/follow_requests", headers: json_bearer_headers(access_token.token)
          expect(response.status_code).to eq(200)
        end

        it "returns JSON" do
          get "/api/v1/follow_requests", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Content-Type"]?).to eq("application/json")
        end

        it "returns all pending requesters" do
          get "/api/v1/follow_requests", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.size).to eq(3)
        end

        it "returns account ids" do
          get "/api/v1/follow_requests", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json.as_a.map(&.dig("id").as_s)).to contain(requester1.id.to_s, requester2.id.to_s, requester3.id.to_s)
        end

        it "includes link header" do
          get "/api/v1/follow_requests?limit=1", headers: json_bearer_headers(access_token.token)
          expect(response.headers["Link"]?).to contain(%Q(rel="next"))
        end
      end
    end
  end

  describe "POST /api/v1/accounts/:id/follow" do
    it "returns 401" do
      post "/api/v1/accounts/0/follow"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)
      let_create(:actor, named: :other)
      let(actor) { account.actor }

      it "returns 404" do
        post "/api/v1/accounts/999999/follow", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        post "/api/v1/accounts/#{other.id}/follow", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns a relationship" do
        post "/api/v1/accounts/#{other.id}/follow", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(other.id.to_s)
      end

      it "sets requested to true" do
        post "/api/v1/accounts/#{other.id}/follow", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["requested"]).to eq(true)
      end

      it "creates a follow relationship" do
        expect { post "/api/v1/accounts/#{other.id}/follow", headers: json_bearer_headers(access_token.token) }
          .to change { Relationship::Social::Follow.count(actor: actor, object: other) }.by(1)
      end

      context "when already following" do
        before_each do
          actor.follow(other, confirmed: true, visible: true).save
        end

        it "does not create a duplicate" do
          expect { post "/api/v1/accounts/#{other.id}/follow", headers: json_bearer_headers(access_token.token) }
            .not_to change { Relationship::Social::Follow.count(actor: actor) }
        end
      end
    end
  end

  describe "POST /api/v1/accounts/:id/unfollow" do
    it "returns 401" do
      post "/api/v1/accounts/0/unfollow"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)
      let_create(:actor, named: :other)
      let(actor) { account.actor }

      it "returns 404" do
        post "/api/v1/accounts/999999/unfollow", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        post "/api/v1/accounts/#{other.id}/unfollow", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns a relationship" do
        post "/api/v1/accounts/#{other.id}/unfollow", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(other.id.to_s)
      end

      context "when following" do
        let_create!(:follow, named: nil, actor: actor, object: other)

        before_each do
          actor.follow(other, confirmed: true, visible: false).save
        end

        it "sets following to false" do
          post "/api/v1/accounts/#{other.id}/unfollow", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["following"]).to eq(false)
        end

        it "destroys the follow relationship" do
          expect { post "/api/v1/accounts/#{other.id}/unfollow", headers: json_bearer_headers(access_token.token) }
            .to change { Relationship::Social::Follow.count(actor: actor, object: other) }.by(-1)
        end
      end
    end
  end

  describe "POST /api/v1/follow_requests/:id/authorize" do
    it "returns 401" do
      post "/api/v1/follow_requests/0/authorize"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)
      let_create(:actor, named: :requester)
      let(actor) { account.actor }

      it "returns 404" do
        post "/api/v1/follow_requests/999999/authorize", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        post "/api/v1/follow_requests/#{requester.id}/authorize", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      context "with a pending follow request" do
        let_create!(:follow, named: nil, actor: requester, object: actor)

        before_each do
          requester.follow(actor, confirmed: false, visible: false).save
        end

        it "sets followed_by to true" do
          post "/api/v1/follow_requests/#{requester.id}/authorize", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["followed_by"]).to eq(true)
        end

        it "confirms the follow relationship" do
          expect { post "/api/v1/follow_requests/#{requester.id}/authorize", headers: json_bearer_headers(access_token.token) }
            .to change { Relationship::Social::Follow.find(actor: requester, object: actor).confirmed }.from(false).to(true)
        end
      end
    end
  end

  describe "POST /api/v1/follow_requests/:id/reject" do
    it "returns 401" do
      post "/api/v1/follow_requests/0/reject"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)
      let_create(:actor, named: :requester)
      let(actor) { account.actor }

      it "returns 404" do
        post "/api/v1/follow_requests/999999/reject", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        post "/api/v1/follow_requests/#{requester.id}/reject", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      context "with a pending follow request" do
        let_create!(:follow, named: nil, actor: requester, object: actor)

        before_each do
          requester.follow(actor, confirmed: false, visible: false).save
        end

        it "sets followed_by to false" do
          post "/api/v1/follow_requests/#{requester.id}/reject", headers: json_bearer_headers(access_token.token)
          json = JSON.parse(response.body)
          expect(json["followed_by"]).to eq(false)
        end

        it "confirms the follow relationship" do
          expect { post "/api/v1/follow_requests/#{requester.id}/reject", headers: json_bearer_headers(access_token.token) }
            .to change { Relationship::Social::Follow.find(actor: requester, object: actor).confirmed }.from(false).to(true)
        end
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
        get "/api/v1/filters", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v1/filters", headers: json_bearer_headers(access_token.token)
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
        get "/api/v2/filters", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v2/filters", headers: json_bearer_headers(access_token.token)
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
        get "/api/v1/markers", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty object" do
        get "/api/v1/markers", headers: json_bearer_headers(access_token.token)
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
        get "/api/v2/notifications/policy", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns for_not_followers" do
        get "/api/v2/notifications/policy", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["for_not_followers"]).to eq("accept")
      end

      it "returns for_not_following" do
        get "/api/v2/notifications/policy", headers: json_bearer_headers(access_token.token)
        json = JSON.parse(response.body)
        expect(json["for_not_following"]).to eq("accept")
      end

      it "returns summary with pending counts" do
        get "/api/v2/notifications/policy", headers: json_bearer_headers(access_token.token)
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
        get "/api/v1/notifications", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v1/notifications", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
      end
    end
  end

  describe "GET /api/v1/lists" do
    it "returns 401" do
      get "/api/v1/lists"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/lists", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v1/lists", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
      end
    end
  end

  describe "GET /api/v1/followed_tags" do
    it "returns 401" do
      get "/api/v1/followed_tags"
      expect(response.status_code).to eq(401)
    end

    context "with valid user access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/followed_tags", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v1/followed_tags", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
      end
    end
  end

  describe "GET /api/v1/custom_emojis" do
    it "succeeds" do
      get "/api/v1/custom_emojis"
      expect(response.status_code).to eq(200)
    end

    it "returns empty array" do
      get "/api/v1/custom_emojis"
      expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
    end
  end

  describe "GET /api/v1/accounts/:id/featured_tags" do
    let_create(:actor)

    it "returns 401" do
      get "/api/v1/accounts/#{actor.id}/featured_tags"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "succeeds" do
        get "/api/v1/accounts/#{actor.id}/featured_tags", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(200)
      end

      it "returns empty array" do
        get "/api/v1/accounts/#{actor.id}/featured_tags", headers: json_bearer_headers(access_token.token)
        expect(JSON.parse(response.body)).to eq(JSON.parse("[]"))
      end

      it "returns 404" do
        get "/api/v1/accounts/999999/featured_tags", headers: json_bearer_headers(access_token.token)
        expect(response.status_code).to eq(404)
      end
    end
  end
end
