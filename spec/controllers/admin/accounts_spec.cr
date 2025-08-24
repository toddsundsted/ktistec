require "../../../src/controllers/admin/accounts"

require "../../spec_helper/controller"
require "../../spec_helper/factory"

Spectator.describe Admin::AccountsController do
  setup_spec

  let(account) { register }

  let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"} }

  describe "GET /admin/accounts" do
    it "returns 401 if not authorized" do
      get "/admin/accounts", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "succeeds" do
        get "/admin/accounts", headers
        expect(response.status_code).to eq(200)
      end

      it "renders add account button" do
        get "/admin/accounts", headers
        expect(response.body).to contain("Add Account")
      end

      it "renders accounts table" do
        get "/admin/accounts", headers
        expect(response.body).to contain("Accounts")
        expect(response.body).to contain("Settings")
      end

      it "includes the authenticated account" do
        get "/admin/accounts", headers
        expect(response.body).to contain(account.username)
      end
    end
  end

  describe "GET /admin/accounts/new" do
    it "returns 401 if not authorized" do
      get "/admin/accounts/new"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "succeeds" do
        get "/admin/accounts/new", headers
        expect(response.status_code).to eq(200)
      end

      it "renders add account form" do
        get "/admin/accounts/new", headers
        expect(response.body).to contain("Add Account")
        expect(response.body).to contain("Username")
        expect(response.body).to contain("Password")
        expect(response.body).to contain("Display Name")
        expect(response.body).to contain("Summary")
      end
    end
  end

  describe "POST /admin/accounts" do
    it "returns 401 if not authorized" do
      post "/admin/accounts"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      it "creates a new account" do
        body = "username=testuser&password=Test123!&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", headers, body: body }.to change { Account.count }.by(1)
        expect(response.status_code).to eq(302)
      end

      it "rejects empty username" do
        body = "username=&password=Test123!&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("username is too short")
      end

      it "rejects short password" do
        body = "username=testuser&password=short&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("password is too short")
      end

      it "rejects weak password" do
        body = "username=testuser&password=weak1234&name=Test+User&summary=A+test+user&language=en&timezone=UTC"
        expect { post "/admin/accounts", headers, body: body }.not_to change { Account.count }
        expect(response.status_code).to eq(422)
        expect(response.body).to contain("password is weak")
      end
    end
  end
end
