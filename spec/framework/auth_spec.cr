require "../spec_helper"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/skip"]

  get "/foo/bar/auth" do |env|
    {account: env.account?, session: env.session?}.to_json
  end

  get "/foo/bar/skip" do |env|
    {account: env.account?, session: env.session?}.to_json
  end
end

Spectator.describe Ktistec::Auth do
  setup_spec

  describe "get /foo/bar/auth" do
    let(payload) { {jti: session.session_key, iat: Time.utc} }
    let(jwt) { Ktistec::JWT.encode(payload) }

    context "anonymous session" do
      let!(session) { Session.new.save }

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(401)
        expect(XML.parse_html(response.body).xpath_nodes("/html//title").first.text).to match(/Unauthorized/)
      end

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(response.status_code).to eq(401)
        expect(JSON.parse(response.body)["msg"]).to eq("Unauthorized")
      end
    end

    context "authenticated session" do
      let(account) { Account.new(random_string, random_string).save }
      let!(session) { Session.new(account).save }

      it "successfully authenticates" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "successfully authenticates" do
        get "/foo/bar/auth", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end
    end
  end

  describe "get /foo/bar/skip" do
    let(payload) { {jti: session.session_key, iat: Time.utc} }
    let(jwt) { Ktistec::JWT.encode(payload) }

    context "anonymous session" do
      let!(session) { Session.new.save }

      it "doesn't authenticate but doesn't fail" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account")).to eq(nil)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "doesn't authenticate but doesn't fail" do
        get "/foo/bar/skip", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account")).to eq(nil)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end
    end

    context "authenticated session" do
      let(account) { Account.new(random_string, random_string).save }
      let!(session) { Session.new(account).save }

      it "successfully authenticates" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "successfully authenticates" do
        get "/foo/bar/skip", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end
    end
  end
end
