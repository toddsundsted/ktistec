require "../spec_helper"

Spectator.describe ActorsController do
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

  it "returns 404 if not found" do
    get "/actors/missing"
    expect(response.status_code).to eq(404)
  end

  it "returns 200 if found" do
    get "/actors/#{username}"
    expect(response.status_code).to eq(200)
  end

  it "responds with HTML" do
    get "/actors/#{username}", HTTP::Headers{"Accept" => "text/html"}
    expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
  end

  it "responds with JSON, by default" do
    get "/actors/#{username}"
    expect(JSON.parse(response.body).dig("type")).to be_truthy
  end
end
