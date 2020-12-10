require "../../../src/framework/ext/context"

require "../../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/session"]

  get "/foo/bar/session" do |env|
    env.session.to_json
  end
end

Spectator.describe HTTP::Server::Context do
  setup_spec

  it "creates a new session" do
    expect{get "/foo/bar/session"}.to change{Session.count}.by(1)
  end

  it "returns the session token in a header" do
    get "/foo/bar/session"
    payload = Ktistec::JWT.decode(response.headers["X-Auth-Token"])
    expect(payload["jti"]).not_to be_nil
  end

  it "returns the session token in a cookie" do
    get "/foo/bar/session"
    payload = Ktistec::JWT.decode(response.cookies["AuthToken"].value)
    expect(payload["jti"]).not_to be_nil
  end

  let(payload) { {jti: session.session_key, iat: Time.utc} }
  let(jwt) { Ktistec::JWT.encode(payload) }

  context "anonymous session" do
    let(session) { Session.new.save }

    it "uses an existing session" do
      get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
      expect(JSON.parse(response.body).dig("session_key")).to eq(session.session_key)
    end

    context "with expired token" do
      let(payload) { {jti: session.session_key, iat: 1.year.ago} }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end

    context "with invalid token" do
      let(payload) { {jti: "invalid session key", iat: Time.utc} }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end

    context "with new secret key" do
      let(jwt) { Ktistec::JWT.encode(payload, "old secret key") }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end
  end

  context "authenticated session" do
    let(account) { Account.new(random_username, random_password).save }
    let(session) { Session.new(account).save }

    it "uses an existing session" do
      get "/foo/bar/session", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
      expect(JSON.parse(response.body).dig("session_key")).to eq(session.session_key)
    end

    context "with expired token" do
      let(payload) { {jti: session.session_key, iat: 1.year.ago} }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end

    context "with invalid token" do
      let(payload) { {jti: "invalid session key", iat: Time.utc} }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end

    context "with new secret key" do
      let(jwt) { Ktistec::JWT.encode(payload, "old secret key") }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Cookie" => "AuthToken=#{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end
  end
end
