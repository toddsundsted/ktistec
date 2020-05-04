require "../spec_helper"

Spectator.describe WellKnownController do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let(username) { random_string }
  let(password) { random_string }

  let!(account) do
    Account.new(username, password).tap do |account|
      account.actor = ActivityPub::Actor.new.tap do |actor|
        actor.username = username
      end.save
    end.save
  end

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
      get "/.well-known/webfinger?resource=acct:missing@test.test"
      expect(response.status_code).to eq(404)
    end

    it "returns 200 if found" do
      get "/.well-known/webfinger?resource=acct:#{username}@test.test"
      expect(response.status_code).to eq(200)
    end

    it "returns the subject" do
      get "/.well-known/webfinger?resource=acct:#{username}@test.test"
      expect(JSON.parse(response.body)["subject"]).to eq("acct:#{username}@test.test")
    end

    it "returns aliases" do
      get "/.well-known/webfinger?resource=acct:#{username}@test.test"
      expect(JSON.parse(response.body)["aliases"]).to match(["https://test.test/actors/#{username}"])
    end

    it "returns reference to the actor document" do
      get "/.well-known/webfinger?resource=acct:#{username}@test.test"
      message = {"rel" => "self", "href" => "https://test.test/actors/#{username}", "type" => "application/activity+json"}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end

    it "returns reference to the profile page" do
      get "/.well-known/webfinger?resource=acct:#{username}@test.test"
      message = {"rel" => "http://webfinger.net/rel/profile-page", "href" => "https://test.test/actors/#{username}", "type" => "text/html"}
      expect(JSON.parse(response.body)["links"].as_a).to contain(message)
    end
  end
end
