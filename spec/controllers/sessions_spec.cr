require "../spec_helper"

Spectator.describe SessionsController do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  def random_string
    ('a'..'z').to_a.shuffle.first(8).join
  end

  let(username) { random_string }
  let(password) { random_string }

  let!(actor) { Actor.new(username, password).save }
  let(session) { Session.new(actor).save }
  let(payload) { {sub: actor.id, jti: session.session_key, iat: Time.utc} }
  let(jwt) { Balloon::JWT.encode(payload) }

  describe "GET /sessions" do
    it "responds with HTML" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/sessions", headers
      expect(response.status_code).to eq(200)
      expect(XML.parse_html(response.body).xpath_nodes("//form[./input[@name='username']][./input[@name='password']]")).not_to be_empty
    end

    it "responds with JSON" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/sessions", headers
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).as_h.keys).to have("username", "password")
    end
  end

  describe "POST /sessions" do
    it "redirects if params are missing" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      post "/sessions", headers
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end

    it "redirects if params are missing" do
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      post "/sessions", headers
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end

    it "rerenders if params are incorrect" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      body = "username=foo&password=bar"
      post "/sessions", headers, body
      expect(response.status_code).to eq(403)
      expect(XML.parse_html(response.body).xpath_nodes("//form[./input]")).not_to be_empty
    end

    it "rerenders if params are incorrect" do
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      body = {username: "foo", password: "bar"}.to_json
      post "/sessions", headers, body
      expect(response.status_code).to eq(403)
      expect(JSON.parse(response.body).as_h.keys).to have("msg", "username", "password")
    end

    it "sets cookie and redirects " do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      body = "username=#{username}&password=#{password}"
      post "/sessions", headers, body
      expect(response.status_code).to eq(302)
      expect(response.headers["Set-Cookie"]).to be_truthy
    end

    it "returns token" do
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      body = {username: username, password: password}.to_json
      post "/sessions", headers, body
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["jwt"]).to be_truthy
    end
  end

  describe "POST /sessions/forget" do
    it "fails to authenticate" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      post "/sessions/forget", headers
      expect(response.status_code).to eq(401)
      expect(XML.parse_html(response.body).xpath_nodes("/html//title").first.text).to eq("Unauthorized")
    end

    it "fails to authenticate" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      post "/sessions/forget", headers
      expect(response.status_code).to eq(401)
      expect(JSON.parse(response.body)["msg"]).to eq("Unauthorized")
    end

    it "destroys session and redirects" do
      headers = HTTP::Headers{"Cookie" => "AuthToken=#{jwt}", "Accept" => "text/html"}
      expect{post "/sessions/forget", headers}.to change{Session.count}.by(-1)
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end

    it "destroys session and redirects" do
      headers = HTTP::Headers{"Authorization" => "Bearer #{jwt}", "Accept" => "application/json"}
      expect{post "/sessions/forget", headers}.to change{Session.count}.by(-1)
      expect(response.status_code).to eq(302)
      expect(response.headers.to_a).to have({"Location", ["/sessions"]})
    end
  end
end
