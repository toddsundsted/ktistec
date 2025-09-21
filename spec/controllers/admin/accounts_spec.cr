require "../../../src/controllers/admin/accounts"

require "../../spec_helper/controller"
require "../../spec_helper/factory"

Spectator.describe Admin::AccountsController do
  setup_spec

  let(account) { register }

  let(http_headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"} }
  let(json_headers) { HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"} }

  describe "GET /admin/accounts" do
    it "returns 401 if not authorized" do
      get "/admin/accounts", http_headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/admin/accounts", json_headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "succeeds" do
        get "/admin/accounts", http_headers
        expect(response.status_code).to eq(200)
        expect(response.headers["Content-Type"]).to eq("text/html")
      end

      it "succeeds" do
        get "/admin/accounts", json_headers
        expect(response.status_code).to eq(200)
        expect(response.headers["Content-Type"]).to eq("application/json")
      end

      it "renders add account button" do
        get "/admin/accounts", http_headers
        expect(response.body).to contain("Add Account")
      end

      it "renders accounts table" do
        get "/admin/accounts", http_headers
        expect(response.body).to contain("Accounts")
        expect(response.body).to contain("Settings")
      end

      it "includes the authenticated account" do
        get "/admin/accounts", http_headers
        expect(response.body).to contain(account.username)
      end

      it "returns accounts array" do
        get "/admin/accounts", json_headers
        json_body = JSON.parse(response.body)
        expect(json_body["accounts"].as_a.size).to eq(1)
        expect(json_body["accounts"][0]["username"]).to eq(account.username)
      end

      context "given two registered accounts" do
        let!(other) { register }

        it "shows indicator only for the authenticated user" do
          get "/admin/accounts", http_headers
          expect(response.body).to contain(account.username)
          expect(response.body).to contain(other.username)
          body = XML.parse_html(response.body)
          expect(body.xpath_nodes("//table/tbody/tr[@id='account-#{account.id}']//i/@class")).to contain("large yellow chess queen icon")
          expect(body.xpath_nodes("//table/tbody/tr[@id='account-#{other.id}']//i/@class")).not_to contain("large yellow chess queen icon")
        end

        it "returns all accounts" do
          get "/admin/accounts", json_headers
          json_body = JSON.parse(response.body)
          expect(json_body["accounts"].as_a.size).to eq(2)
          expect(json_body["accounts"][0]["username"]).to eq(account.username)
          expect(json_body["accounts"][1]["username"]).to eq(other.username)
        end
      end
    end
  end

  describe "GET /admin/accounts/new" do
    it "returns 401 if not authorized" do
      get "/admin/accounts/new", http_headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/admin/accounts/new", json_headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "succeeds" do
        get "/admin/accounts/new", http_headers
        expect(response.status_code).to eq(200)
        expect(response.headers["Content-Type"]).to eq("text/html")
      end

      it "succeeds" do
        get "/admin/accounts/new", json_headers
        expect(response.status_code).to eq(200)
        expect(response.headers["Content-Type"]).to eq("application/json")
      end

      it "renders add account form" do
        get "/admin/accounts/new", http_headers
        expect(response.body).to contain("Add Account")
        expect(response.body).to contain("Username")
        expect(response.body).to contain("Password")
        expect(response.body).to contain("Display Name")
        expect(response.body).to contain("Summary")
      end

      it "returns empty account" do
        get "/admin/accounts/new", json_headers
        json_body = JSON.parse(response.body)
        expect(json_body["account"]["username"].as_s).to eq("")
        expect(json_body["account"]["password"].as_s).to eq("")
        expect(json_body["actor"]["name"].as_nil).to be_nil
        expect(json_body["actor"]["summary"].as_nil).to be_nil
      end
    end
  end

  describe "POST /admin/accounts" do
    it "returns 401 if not authorized" do
      post "/admin/accounts", http_headers, body: ""
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      post "/admin/accounts", json_headers, body: "{}"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "creates a new account" do
        body = "username=testuser&password=Test123!&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", http_headers, body: body }.to change { Account.count }.by(1)
        expect(response.status_code).to eq(302)
      end

      it "creates a new account" do
        body = {"username" => "testuser", "password" => "Test123@", "name" => "Test User", "summary" => "A test user", "language" => "en", "timezone" => "UTC"}.to_json
        expect { post "/admin/accounts", json_headers, body: body }.to change { Account.count }.by(1)
        expect(response.status_code).to eq(201)
      end

      it "rejects empty username" do
        body = "username=&password=Test123!&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", http_headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("username is too short")
      end

      it "rejects empty username" do
        body = {"username" => "", "password" => "Test123@", "name" => "Test User", "summary" => "A test user", "language" => "en", "timezone" => "UTC"}.to_json
        expect { post "/admin/accounts", json_headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_a).to contain({"username" => ["is too short"]})
      end

      it "rejects short password" do
        body = "username=testuser&password=short&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", http_headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("password is too short", "password is weak")
      end

      it "rejects short password" do
        body = {"username" => "testuser", "password" => "short", "name" => "Test User", "summary" => "A test user", "language" => "en", "timezone" => "UTC"}.to_json
        expect { post "/admin/accounts", json_headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_a).to contain({"password" => ["is too short", "is weak"]})
      end

      it "rejects weak password" do
        body = "username=testuser&password=weak1234&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", http_headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("password is weak")
      end

      it "rejects weak password" do
        body = {"username" => "testuser", "password" => "weak1234", "name" => "Test User", "summary" => "A test user", "language" => "en", "timezone" => "UTC"}.to_json
        expect { post "/admin/accounts", json_headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_a).to contain({"password" => ["is weak"]})
      end
    end
  end
end
