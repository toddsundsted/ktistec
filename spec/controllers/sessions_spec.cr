require "../../src/controllers/sessions"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe SessionsController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}

  let(username) { random_username }
  let(password) { random_password }

  let_create!(:account, username: username, password: password)
  let(session) { Session.new(account).save }
  let(payload) { {jti: session.session_key, iat: Time.utc} }
  let(jwt) { Ktistec::JWT.encode(payload) }

  describe "GET /sessions" do
    it "responds with HTML" do
      get "/sessions", HTML_HEADERS
      expect(response.status_code).to eq(200)
      expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='username']][.//input[@name='password']]")).not_to be_empty
    end

    it "responds with JSON" do
      get "/sessions", JSON_HEADERS
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).as_h.keys).to have("username", "password")
    end
  end

  describe "POST /sessions" do
    it "redirects if params are missing" do
      post "/sessions", HTML_HEADERS
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end

    it "redirects if params are missing" do
      post "/sessions", JSON_HEADERS
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end

    it "rerenders if params are incorrect" do
      body = "username=foo&password=bar"
      post "/sessions", HTML_HEADERS, body
      expect(response.status_code).to eq(403)
      expect(XML.parse_html(response.body).xpath_nodes("//form[./input]")).not_to be_empty
    end

    it "rerenders if params are incorrect" do
      body = {username: "foo", password: "bar"}.to_json
      post "/sessions", JSON_HEADERS, body
      expect(response.status_code).to eq(403)
      expect(JSON.parse(response.body).as_h.keys).to have("errors", "username", "password")
    end

    it "sets cookie and redirects " do
      body = "username=#{username}&password=#{password}"
      post "/sessions", HTML_HEADERS, body
      expect(response.status_code).to eq(302)
      expect(response.headers["Set-Cookie"]).to be_truthy
    end

    it "returns token" do
      body = {username: username, password: password}.to_json
      post "/sessions", JSON_HEADERS, body
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["jwt"]).to be_truthy
    end

    context "given a redirect path in the session" do
      before_each { session.string("redirect_after_auth_path", "/foo/bar/baz") }

      it "redirects to the path" do
        body = "username=#{username}&password=#{password}"
        post "/sessions", HTML_HEADERS.add("Cookie", "__Host-AuthToken=#{jwt}"), body
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/foo/bar/baz"]})
      end

      it "returns the path" do
        body = {username: username, password: password}.to_json
        post "/sessions", JSON_HEADERS.add("Authorization", "Bearer #{jwt}"), body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["redirect_path"]).to eq("/foo/bar/baz")
      end
    end

    context "cookie attributes" do
      it "sets a secure, host-only cookie" do
        body = "username=#{username}&password=#{password}"
        post "/sessions", HTML_HEADERS, body

        expect(response.status_code).to eq(302)

        set_cookie_header = response.headers["Set-Cookie"]
        expect(set_cookie_header).to contain("__Host-AuthToken=")
        expect(set_cookie_header).to contain("path=/")
        expect(set_cookie_header).to contain("HttpOnly")
        expect(set_cookie_header).to contain("Secure")
      end
    end
  end

  describe "DELETE /sessions" do
    it "fails to authenticate" do
      delete "/sessions", HTML_HEADERS
      expect(response.status_code).to eq(401)
      expect(XML.parse_html(response.body).xpath_nodes("/html//title").first).to match(/Unauthorized/)
    end

    it "fails to authenticate" do
      delete "/sessions", JSON_HEADERS
      expect(response.status_code).to eq(401)
      expect(JSON.parse(response.body)["msg"]).to eq("Unauthorized")
    end

    it "destroys session and redirects" do
      headers = HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}", "Accept" => "text/html"}
      expect{delete "/sessions", headers}.to change{Session.count}.by(-1)
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end

    it "destroys session and redirects" do
      headers = HTTP::Headers{"Authorization" => "Bearer #{jwt}", "Accept" => "application/json"}
      expect{delete "/sessions", headers}.to change{Session.count}.by(-1)
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end
  end
end
