require "../../src/framework/auth"
require "../../src/framework/controller"

require "../spec_helper/controller"
require "../spec_helper/factory"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/skip"]

  get "/foo/bar/auth" do |env|
    {account: env.account?, session: env.session?}.to_json
  end

  post "/foo/bar/auth" do |env|
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
        expect(XML.parse_html(response.body).xpath_nodes("/html//title").first).to match(/Unauthorized/)
      end

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "application/json", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.status_code).to eq(401)
        expect(JSON.parse(response.body)["msg"]).to eq("Unauthorized")
      end

      it "stores the path in the session" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(session.reload!.string?("redirect_after_auth_path")).to eq("/foo/bar/auth")
      end

      it "doesn't store the path in the session" do
        post "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(session.reload!.string?("redirect_after_auth_path")).to be_nil
      end

      it "doesn't store the path in the session" do
        get "/foo/bar/auth", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(session.reload!.string?("redirect_after_auth_path")).to be_nil
      end
    end

    context "authenticated session" do
      let(account) { register }
      let!(session) { Session.new(account).save }

      it "successfully authenticates" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "successfully authenticates" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "application/json", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "doesn't store the path in the session" do
        get "/foo/bar/auth", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(session.reload!.string?("redirect_after_auth_path")).to be_nil
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
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "application/json", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account")).to eq(nil)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "doesn't store the path in the session" do
        get "/foo/bar/skip", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(session.reload!.string?("redirect_after_auth_path")).to be_nil
      end
    end

    context "authenticated session" do
      let(account) { register }
      let!(session) { Session.new(account).save }

      it "successfully authenticates" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "successfully authenticates" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "application/json", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
        expect(JSON.parse(response.body).dig("session", "session_key")).to eq(session.session_key)
      end

      it "doesn't store the path in the session" do
        get "/foo/bar/skip", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(session.reload!.string?("redirect_after_auth_path")).to be_nil
      end
    end
  end
end
