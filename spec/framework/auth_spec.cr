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

      it "sets redirect cookie" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        cookie = response.cookies["__Host-RedirectPath"]?
        expect(cookie).not_to be_nil
        expect(cookie.not_nil!.value).to eq("/foo/bar/auth")
        expect(cookie.not_nil!.http_only).to be_true
        expect(cookie.not_nil!.secure).to be_true
        expect(cookie.not_nil!.samesite).to eq(HTTP::Cookie::SameSite::Lax)
        expect(cookie.not_nil!.max_age).to eq(5.minutes)
        expect(cookie.not_nil!.path).to eq("/")
      end

      it "doesn't set a redirect cookie" do
        post "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
      end

      it "doesn't set a redirect cookie" do
        get "/foo/bar/auth", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
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

      it "doesn't set a redirect cookie" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
      end
    end

    context "with a bearer token" do
      let(account) { register }
      let_create(:oauth2_provider_client, named: :client)
      let_create!(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "text/html", "Authorization" => "Bearer #{access_token.token}"}
        expect(response.status_code).to eq(401)
      end

      it "fails to authenticate" do
        get "/foo/bar/auth", HTTP::Headers{"Accept" => "application/json", "Authorization" => "Bearer #{access_token.token}"}
        expect(response.status_code).to eq(401)
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

      it "doesn't set a redirect cookie" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
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

      it "doesn't set a redirect cookie" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "text/html", "Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(response.cookies["__Host-RedirectPath"]?).to be_nil
      end
    end

    context "with a bearer token" do
      let(account) { register }
      let_create(:oauth2_provider_client, named: :client)
      let_create!(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

      it "proceeds" do
        get "/foo/bar/skip", HTTP::Headers{"Accept" => "application/json", "Authorization" => "Bearer #{access_token.token}"}
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("account", "id")).to eq(account.id)
      end
    end
  end
end
