require "../spec_helper"

class FooBarController
  include Balloon::Controller

  ID = random_string
  ACTIVITY = ActivityPub::Activity.new(iri: "https://remote/#{ID}").save
  OBJECT = ActivityPub::Object.new(iri: "https://remote/#{ID}").save
  ACTOR = ActivityPub::Actor.new(iri: "https://remote/#{ID}").save

  skip_auth [
    "/foo/bar/helpers",
    "/foo/bar/helpers/activities",
    "/foo/bar/helpers/activities/:id",
    "/foo/bar/helpers/objects",
    "/foo/bar/helpers/objects/:id",
    "/foo/bar/helpers/actors",
    "/foo/bar/helpers/actors/:username",
    "/foo/bar/helpers/:id/:relationship",
    "/foo/bar/paginate",
    "/foo/bar/accept",
    "/foo/bar/escape",
    "/foo/bar/sanitize"
  ]

  get "/foo/bar/helpers" do |env|
    {
      host: host,
      home_path: home_path,
      sessions_path: sessions_path,
      back_path: back_path
    }.to_json
  end

  get "/foo/bar/helpers/activities" do |env|
    {
      remote_activity_path: remote_activity_path(ACTIVITY),
      activity_path: activity_path(ACTIVITY)
    }.to_json
  end

  get "/foo/bar/helpers/activities/:id" do |env|
    {
      remote_activity_path: remote_activity_path,
      activity_path: activity_path
    }.to_json
  end

  get "/foo/bar/helpers/objects" do |env|
    {
      remote_object_path: remote_object_path(OBJECT),
      object_path: object_path(OBJECT)
    }.to_json
  end

  get "/foo/bar/helpers/objects/:id" do |env|
    {
      remote_object_path: remote_object_path,
      object_path: object_path
    }.to_json
  end

  get "/foo/bar/helpers/actors" do |env|
    {
      remote_actor_path: remote_actor_path(ACTOR),
      actor_path: actor_path(ACTOR)
    }.to_json
  end

  get "/foo/bar/helpers/actors/:id" do |env|
    {
      remote_actor_path: remote_actor_path,
      actor_path: actor_path
    }.to_json
  end

  get "/foo/bar/helpers/:id/:relationship" do |env|
    {
      actor_relationships_path: actor_relationships_path
    }.to_json
  end

  get "/foo/bar/paginate" do |env|
    page = env.params.query["page"]?.try(&.to_i) || 0
    size = env.params.query["size"]?.try(&.to_i) || 10
    results = Balloon::Util::PaginatedArray(Int32).new
    (0..9).to_a[page * size, size].each { |v| results << v }
    results.more = (page + 1) * size < 10
    paginate(results, env)
  end

  get "/foo/bar/accept" do |env|
    if accepts?("text/html")
      "html"
    elsif accepts?("application/json")
      "json"
    end
  end

  get "/foo/bar/escape" do |env|
    e "foo\nbar"
  end

  get "/foo/bar/sanitize" do |env|
    s "<body>Foo Bar</body>"
  end
end

Spectator.describe Balloon::Controller do
  describe "get /foo/bar/helpers" do
    it "gets the host" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["host"]).to eq("https://test.test")
    end

    it "gets the home path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["home_path"]).to eq("/")
    end

    it "gets the sessions path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["sessions_path"]).to eq("/sessions")
    end

    it "gets the back path" do
      get "/foo/bar/helpers", HTTP::Headers{"Referer" => "/back"}
      expect(JSON.parse(response.body)["back_path"]).to eq("/back")
    end

    it "gets the remote activity path" do
      get "/foo/bar/helpers/activities"
      expect(JSON.parse(response.body)["remote_activity_path"]).to eq("/remote/activities/#{FooBarController::ACTIVITY.id}")
      get "/foo/bar/helpers/activities/999999"
      expect(JSON.parse(response.body)["remote_activity_path"]).to eq("/remote/activities/999999")
    end

    it "gets the activity path" do
      get "/foo/bar/helpers/activities"
      expect(JSON.parse(response.body)["activity_path"]).to eq("/#{FooBarController::ID}")
      get "/foo/bar/helpers/activities/foo_bar"
      expect(JSON.parse(response.body)["activity_path"]).to eq("/activities/foo_bar")
    end

    it "gets the remote object path" do
      get "/foo/bar/helpers/objects"
      expect(JSON.parse(response.body)["remote_object_path"]).to eq("/remote/objects/#{FooBarController::OBJECT.id}")
      get "/foo/bar/helpers/objects/999999"
      expect(JSON.parse(response.body)["remote_object_path"]).to eq("/remote/objects/999999")
    end

    it "gets the object path" do
      get "/foo/bar/helpers/objects"
      expect(JSON.parse(response.body)["object_path"]).to eq("/#{FooBarController::ID}")
      get "/foo/bar/helpers/objects/foo_bar"
      expect(JSON.parse(response.body)["object_path"]).to eq("/objects/foo_bar")
    end

    it "gets the remote actor path" do
      get "/foo/bar/helpers/actors"
      expect(JSON.parse(response.body)["remote_actor_path"]).to eq("/remote/actors/#{FooBarController::ACTOR.id}")
      get "/foo/bar/helpers/actors/999999"
      expect(JSON.parse(response.body)["remote_actor_path"]).to eq("/remote/actors/999999")
    end

    it "gets the actor path" do
      get "/foo/bar/helpers/actors"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/#{FooBarController::ID}")
      get "/foo/bar/helpers/actors/foo_bar"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/foo_bar")
    end

    it "gets the actor relationships path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(JSON.parse(response.body)["actor_relationships_path"]).to eq("/actors/foo_bar/helping")
    end
  end

  describe "get /foo/bar/paginate" do
    it "does not display pagination controls" do
      get "/foo/bar/paginate"
      expect(XML.parse_html(response.body).xpath_nodes("//a")).to be_empty
    end

    it "displays the prev link" do
      get "/foo/bar/paginate?page=1"
      expect(XML.parse_html(response.body).xpath_nodes("//a[contains(text(),'Prev')]")).not_to be_empty
    end

    it "displays the next link" do
      get "/foo/bar/paginate?size=9"
      expect(XML.parse_html(response.body).xpath_nodes("//a[contains(text(),'Next')]")).not_to be_empty
    end
  end

  describe "get /foo/bar/accept" do
    it "responds with HTML" do
      get "/foo/bar/accept", HTTP::Headers{"Accept" => "text/html"}
      expect(response.body).to eq("html")
    end

    it "responds with JSON" do
      get "/foo/bar/accept", HTTP::Headers{"Accept" => "application/json"}
      expect(response.body).to eq("json")
    end
  end

  describe "/foo/bar/escape" do
    it "escapes newline characters" do
      get "/foo/bar/escape"
      expect(response.body).to eq("foo\\nbar")
    end
  end

  describe "/foo/bar/sanitize" do
    it "sanitizes HTML" do
      get "/foo/bar/sanitize"
      expect(response.body).to eq("<p>Foo Bar</p>")
    end
  end
end
