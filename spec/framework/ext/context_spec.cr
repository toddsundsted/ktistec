require "../../../src/framework/ext/context"
require "../../../src/framework/controller"

require "../../spec_helper/controller"
require "../../spec_helper/factory"

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
    expect { get "/foo/bar/session" }.to change { Session.count }.by(1)
  end

  it "returns the session token in a cookie" do
    get "/foo/bar/session"
    payload = Ktistec::JWT.decode(response.cookies["__Host-AuthToken"].value)
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

  context "JWT authenticated session" do
    let(account) { register }
    let!(session) { Session.new(account).save }

    it "uses an existing session" do
      get "/foo/bar/session", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
      expect(JSON.parse(response.body).dig("session_key")).to eq(session.session_key)
    end

    context "with expired token" do
      let(payload) { {jti: session.session_key, iat: 1.year.ago} }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end

    context "with invalid token" do
      let(payload) { {jti: "invalid session key", iat: Time.utc} }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end

    context "with new secret key" do
      let(jwt) { Ktistec::JWT.encode(payload, "old secret key") }

      it "creates a new session" do
        get "/foo/bar/session", HTTP::Headers{"Cookie" => "__Host-AuthToken=#{jwt}"}
        expect(JSON.parse(response.body).dig("session_key")).not_to eq(session.session_key)
      end
    end
  end

  context "OAuth authenticated session" do
    let(account) { register }
    let_create(:oauth2_provider_client, named: :client)
    let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account)

    it "creates a new session" do
      expect { get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"} }
        .to change { Session.count }.by(1)
    end

    it "links the session to the access token" do
      get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"}
      expect(Session.all.last.oauth_access_token_id).to eq(access_token.id)
    end

    it "authenticates the session with the account from the access token" do
      get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"}
      expect(Session.all.last.account_id).to eq(account.id)
    end

    context "given an existing session" do
      let!(session) { Session.new(account: account, oauth_access_token: access_token).save }

      it "does not create a new session" do
        expect { get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"} }
          .not_to change { Session.count }
      end
    end

    context "with expired access token" do
      let_create(:oauth2_provider_access_token, named: :access_token, client: client, account: account, expires_at: 1.day.ago)

      it "creates a new session" do
        expect { get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"} }
          .to change { Session.count }.by(1)
      end

      it "does not link session to the access token" do
        get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"}
        expect(Session.all.last.oauth_access_token_id).to be_nil
      end

      it "creates an anonymous session" do
        get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer #{access_token.token}"}
        expect(Session.all.last.account_id).to be_nil
      end
    end

    context "with invalid access token" do
      it "creates an anonymous session" do
        get "/foo/bar/session", HTTP::Headers{"Authorization" => "Bearer invalid_token_string"}
        expect(Session.all.last.account_id).to be_nil
      end
    end
  end
end
