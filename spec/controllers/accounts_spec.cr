require "../spec_helper"

Spectator.describe AccountsController do
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
    get "/accounts/missing"
    expect(response.status_code).to eq(404)
  end

  it "returns 200 if found" do
    get "/accounts/#{username}"
    expect(response.status_code).to eq(200)
  end

  it "responds with HTML" do
    get "/accounts/#{username}", HTTP::Headers{"Accept" => "text/html"}
    expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
  end

  it "responds with JSON, by default" do
    get "/accounts/#{username}"
    expect(JSON.parse(response.body).dig("type")).to be_truthy
  end
end
