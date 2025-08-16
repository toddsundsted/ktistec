require "../../src/controllers/well_known"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe WellKnownController do
  setup_spec

  let(username) { random_username }
  let(password) { random_password }

  let!(account) { register(username, password) }

  context "webfinger" do
    it "returns 400 if bad request" do
      get "/.well-known/webfinger"
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if bad request" do
      get "/.well-known/webfinger?resource="
      expect(response.status_code).to eq(400)
    end

    # actor

    it "returns 400 if bad host" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40remote"
      expect(response.status_code).to eq(400)
    end

    it "returns 404 if not found" do
      get "/.well-known/webfinger?resource=acct%3Amissing%40test.test"
      expect(response.status_code).to eq(404)
    end

    it "returns 200 if found" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
      expect(response.status_code).to eq(200)
    end

    it "returns 200 if 'acct' URI scheme is missing" do
      get "/.well-known/webfinger?resource=#{username}%40test.test"
      expect(response.status_code).to eq(200)
    end

    it "returns 200 if 'https' URI scheme is used" do
      get "/.well-known/webfinger?resource=https%3A%2F%2Ftest.test%2Factors%2F#{username}"
      expect(response.status_code).to eq(200)
    end

    it "returns 200 if 'https' URI scheme is used" do
      get "/.well-known/webfinger?resource=https%3A%2F%2Ftest.test%2F%40#{username}"
      expect(response.status_code).to eq(200)
    end

    it "returns the handle in the subject" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
      expect(JSON.parse(response.body)["subject"]).to eq("acct:#{username}@test.test")
    end

    it "returns the handle in the subject if 'acct' URI scheme is missing" do
      get "/.well-known/webfinger?resource=#{username}%40test.test"
      expect(JSON.parse(response.body)["subject"]).to eq("acct:#{username}@test.test")
    end

    it "returns the handle in the subject if 'https' URI scheme is used" do
      get "/.well-known/webfinger?resource=https%3A%2F%2Ftest.test%2Factors%2F#{username}"
      expect(JSON.parse(response.body)["subject"]).to eq("acct:#{username}@test.test")
    end

    it "returns the handle in the subject if 'https' URI scheme is used" do
      get "/.well-known/webfinger?resource=https%3A%2F%2Ftest.test%2F%40#{username}"
      expect(JSON.parse(response.body)["subject"]).to eq("acct:#{username}@test.test")
    end

    it "returns aliases" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
      expect(JSON.parse(response.body)["aliases"]).to match(["https://test.test/actors/#{username}"])
    end

    it "returns reference to the actor document" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
      message = {"rel" => "self", "href" => "https://test.test/actors/#{username}", "type" => %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end

    it "returns reference to the profile page" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
      message = {"rel" => "http://webfinger.net/rel/profile-page", "href" => "https://test.test/@#{username}", "type" => "text/html"}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end

    it "returns reference to the template" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
      message = {"rel" => "http://ostatus.org/schema/1.0/subscribe", "template" => "https://test.test/authorize-interaction?uri={uri}"}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end

    # host

    it "returns 400 if bad host" do
      get "/.well-known/webfinger?resource=remote"
      expect(response.status_code).to eq(400)
    end

    it "returns 200 if found" do
      get "/.well-known/webfinger?resource=test.test"
      expect(response.status_code).to eq(200)
    end

    it "returns 200 if 'https' URI scheme is used" do
      get "/.well-known/webfinger?resource=https://test.test"
      expect(response.status_code).to eq(200)
    end

    it "returns the domain in the subject" do
      get "/.well-known/webfinger?resource=test.test"
      expect(JSON.parse(response.body)["subject"]).to eq("test.test")
    end

    it "returns the domain in the subject if 'https' URI scheme is used" do
      get "/.well-known/webfinger?resource=https://test.test"
      expect(JSON.parse(response.body)["subject"]).to eq("test.test")
    end

    it "returns aliases" do
      get "/.well-known/webfinger?resource=test.test"
      expect(JSON.parse(response.body)["aliases"]).to match(["https://test.test"])
    end

    it "returns reference to the template" do
      get "/.well-known/webfinger?resource=test.test"
      message = {"rel" => "http://ostatus.org/schema/1.0/subscribe", "template" => "https://test.test/authorize-interaction?uri={uri}"}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end
  end

  context "nodeinfo" do
    it "returns 200" do
      get "/.well-known/nodeinfo"
      expect(response.status_code).to eq(200)
    end

    it "returns reference to the nodeinfo document" do
      get "/.well-known/nodeinfo"
      message = {"rel" => "http://nodeinfo.diaspora.software/ns/schema/2.1", "href" => "https://test.test/.well-known/nodeinfo/2.1"}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end

    it "returns the version" do
      get "/.well-known/nodeinfo/2.1"
      expect(JSON.parse(response.body)["version"].as_s).to eq("2.1")
    end

    it "returns software" do
      get "/.well-known/nodeinfo/2.1"
      message = {"name" => "ktistec", "version" => Ktistec::VERSION, "repository" => "https://github.com/toddsundsted/ktistec", "homepage" => "https://ktistec.com/"}
      expect(JSON.parse(response.body)["software"].as_h).to eq(message)
    end

    it "returns protocols" do
      get "/.well-known/nodeinfo/2.1"
      message = ["activitypub"]
      expect(JSON.parse(response.body)["protocols"].as_a).to eq(message)
    end

    it "returns services" do
      get "/.well-known/nodeinfo/2.1"
      message = {"inbound" => [] of String, "outbound" => [] of String}
      expect(JSON.parse(response.body)["services"].as_h).to eq(message)
    end

    it "returns open registrations" do
      get "/.well-known/nodeinfo/2.1"
      expect(JSON.parse(response.body)["openRegistrations"].as_bool).to be_false
    end

    it "returns usage" do
      get "/.well-known/nodeinfo/2.1"
      message = {"users" => {"total" => 1}, "localPosts" => 0}
      expect(JSON.parse(response.body)["usage"].as_h).to eq(message)
    end

    it "returns metadata" do
      get "/.well-known/nodeinfo/2.1"
      message = {"siteName" => "Test"}
      expect(JSON.parse(response.body)["metadata"].as_h).to eq(message)
    end
  end

  {% begin %}
    {% for path in ["oauth-protected-resource", "oauth-protected-resource/mcp"] %}
      context {{path}} do
        it "returns 200" do
          get "/.well-known/{{path.id}}"
          expect(response.status_code).to eq(200)
        end

        it "returns the resource identifier" do
          get "/.well-known/{{path.id}}"
          expect(JSON.parse(response.body)["resource"]).to eq("https://test.test")
        end

        it "returns the authorization servers" do
          get "/.well-known/{{path.id}}"
          expect(JSON.parse(response.body)["authorization_servers"]).to eq(["https://test.test"])
        end

        it "returns the scopes supported" do
          get "/.well-known/{{path.id}}"
          expect(JSON.parse(response.body)["scopes_supported"]).to eq(["mcp"])
        end

        it "returns the bearer methods supported" do
          get "/.well-known/{{path.id}}"
          expect(JSON.parse(response.body)["bearer_methods_supported"]).to eq(["header"])
        end

        it "sets CORS headers" do
          get "/.well-known/{{path.id}}"
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(response.headers["Access-Control-Allow-Methods"]).to eq("OPTIONS, GET")
          expect(response.headers["Access-Control-Allow-Headers"]).to match(/MCP-Protocol-Version/)
        end

        it "sets the content type" do
          get "/.well-known/{{path.id}}"
          expect(response.headers["Content-Type"]).to eq("application/json")
        end
      end
    {% end %}
  {% end %}

  context "oauth-authorization-server" do
    it "returns 200" do
      get "/.well-known/oauth-authorization-server"
      expect(response.status_code).to eq(200)
    end

    it "returns the issuer" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["issuer"]).to eq("https://test.test")
    end

    it "returns the registration endpoint" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["registration_endpoint"]).to eq("https://test.test/oauth/register")
    end

    it "returns the authorization endpoint" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["authorization_endpoint"]).to eq("https://test.test/oauth/authorize")
    end

    it "returns the token endpoint" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["token_endpoint"]).to eq("https://test.test/oauth/token")
    end

    it "returns the scopes supported" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["scopes_supported"]).to eq(["mcp"])
    end

    it "returns the response types supported" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["response_types_supported"]).to eq(["code"])
    end

    it "returns the grant types supported" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["grant_types_supported"]).to eq(["authorization_code"])
    end

    it "returns the token endpoint auth methods supported" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["token_endpoint_auth_methods_supported"]).to eq(["client_secret_basic"])
    end

    it "returns the code challenge methods supported" do
      get "/.well-known/oauth-authorization-server"
      expect(JSON.parse(response.body)["code_challenge_methods_supported"]).to eq(["S256"])
    end

    it "sets CORS headers" do
      get "/.well-known/oauth-authorization-server"
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Allow-Methods"]).to eq("OPTIONS, GET")
      expect(response.headers["Access-Control-Allow-Headers"]).to match(/MCP-Protocol-Version/)
    end

    it "sets the content type" do
      get "/.well-known/oauth-authorization-server"
      expect(response.headers["Content-Type"]).to eq("application/json")
    end
  end
end
