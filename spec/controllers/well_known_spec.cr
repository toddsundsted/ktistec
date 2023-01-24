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

    it "returns the subject" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
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
      message = {"rel" => "http://ostatus.org/schema/1.0/subscribe", "template" => "https://test.test/actors/#{username}/authorize-follow?uri={uri}"}
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
end
