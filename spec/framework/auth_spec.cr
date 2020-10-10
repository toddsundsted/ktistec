require "../spec_helper"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/skip"]

  get "/foo/bar/auth" do |env|
    {account: env.current_account?, session: env.current_session?}.to_json
  end

  get "/foo/bar/skip" do |env|
    {account: env.current_account?, session: env.current_session?}.to_json
  end
end

Spectator.describe Ktistec::Auth do
  setup_spec

  let(username) { random_string }
  let(password) { random_string }

  let(account) { Account.new(username, password).save }
  let(session) { Session.new(account).save }
  let(payload) { {jti: session.session_key, iat: Time.utc} }
  let(jwt) { Ktistec::JWT.encode(payload) }

  describe "get /foo/bar/auth" do
    it "successfully authenticates" do
      get "/foo/bar/auth", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
      expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
    end

    it "successfully authenticates" do
      get "/foo/bar/auth", HTTP::Headers{"Cookie" => "one=two; AuthToken=#{jwt}"}
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
      expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
    end

    it "fails to authenticate, as HTML" do
      get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html"}
      expect(response.status_code).to eq(401)
      expect(XML.parse_html(response.body).xpath_nodes("/html//title").first.text).to match(/Unauthorized/)
    end

    it "fails to authenticate" do
      get "/foo/bar/auth"
      expect(response.status_code).to eq(401)
      expect(JSON.parse(response.body)["msg"]).to eq("Unauthorized")
    end

    context "invalid session" do
      let(payload) { {jti: "invalid session key", iat: Time.utc} }

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(401)
      end
    end

    context "invalid time" do
      let(payload) { {jti: session.session_key, iat: Time.utc - 1.year} }

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Cookie" => "one=two; AuthToken=#{jwt}"}
        expect(response.status_code).to eq(401)
      end
    end

    context "new secret key" do
      let(jwt) { Ktistec::JWT.encode(payload, "old secret key") }

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(401)
      end
    end
  end

  describe "get /foo/bar/skip" do
    it "successfully authenticates" do
      get "/foo/bar/skip", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
      expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
    end

    it "successfully authenticates" do
      get "/foo/bar/skip", HTTP::Headers{"Cookie" => "one=two; AuthToken=#{jwt}"}
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
      expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
    end

    it "doesn't authenticate and doesn't fail" do
      get "/foo/bar/skip"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body).dig("account")).to eq(nil)
      expect(JSON.parse(response.body).dig("session")).to eq(nil)
    end
  end
end
