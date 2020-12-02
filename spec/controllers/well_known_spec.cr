require "../spec_helper"

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

    it "returns 404 if not found" do
      get "/.well-known/webfinger?resource=acct%3Amissing%40test.test"
      expect(response.status_code).to eq(404)
    end

    it "returns 200 if found" do
      get "/.well-known/webfinger?resource=acct%3A#{username}%40test.test"
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
      message = {"rel" => "self", "href" => "https://test.test/actors/#{username}", "type" => "application/activity+json"}
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
end
