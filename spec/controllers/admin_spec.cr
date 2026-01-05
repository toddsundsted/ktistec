require "../../src/controllers/admin"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe AdminController do
  setup_spec

  let(account) { register }

  describe "GET /admin" do
    it "returns 401 if not authorized" do
      get "/admin"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: account.username)

      context "and accepting HTML" do
        let(headers) { HTTP::Headers{"Accept" => "text/html"} }

        it "succeeds" do
          get "/admin", headers
          expect(response.status_code).to eq(200)
        end

        it "renders the admin dashboard" do
          get "/admin", headers
          expect(XML.parse_html(response.body).xpath_nodes("//h1[text()='Admin']")).not_to be_empty
        end

        it "renders links to admin functionality" do
          get "/admin", headers
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/settings' and text()='Settings']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/system' and text()='Logging Levels']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/metrics' and text()='Metrics']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/tasks' and text()='Tasks']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/filters' and text()='Filters']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/admin/accounts' and text()='Accounts']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/admin/oauth/clients' and text()='OAuth Clients']")).not_to be_empty
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='/admin/oauth/tokens' and text()='OAuth Tokens']")).not_to be_empty
        end
      end
    end
  end
end
