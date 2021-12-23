require "../../src/framework/controller"

require "../spec_helper/factory"
require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  # assigned in the specs, below
  class_property! activity : ActivityPub::Activity
  class_property! object : ActivityPub::Object
  class_property! actor : ActivityPub::Actor

  skip_auth [
    "/foo/bar/helpers",
    "/foo/bar/helpers/activities",
    "/foo/bar/helpers/activities/:id",
    "/foo/bar/helpers/objects",
    "/foo/bar/helpers/objects/:id",
    "/foo/bar/helpers/actors",
    "/foo/bar/helpers/actors/by-id/:id",
    "/foo/bar/helpers/actors/by-username/:username",
    "/foo/bar/helpers/:username/:relationship",
    "/foo/bar/accepts",
    "/foo/bar/xhr",
    "/foo/bar/created",
    "/foo/bar/redirect",
    "/foo/bar/sanitize",
    "/foo/bar/pluralize",
    "/foo/bar/comma",
    "/foo/bar/id",
    "/foo/bar/ok"
  ]

  get "/foo/bar/helpers" do |env|
    {
      host: host,
      home_path: home_path,
      sessions_path: sessions_path,
      back_path: back_path,
      thread_path: thread_path(object),
      remote_thread_path: remote_thread_path(object),
      anchor: anchor(object)
    }.to_json
  end

  get "/foo/bar/helpers/activities" do |env|
    {
      remote_activity_path: remote_activity_path(activity),
      activity_path: activity_path(activity)
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
      remote_object_path: remote_object_path(object),
      object_path: object_path(object)
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
      remote_actor_path: remote_actor_path(actor),
      actor_path: actor_path(actor)
    }.to_json
  end

  get "/foo/bar/helpers/actors/by-id/:id" do |env|
    {
      remote_actor_path: remote_actor_path
    }.to_json
  end

  get "/foo/bar/helpers/actors/by-username/:username" do |env|
    {
      actor_path: actor_path
    }.to_json
  end

  get "/foo/bar/helpers/:username/:relationship" do |env|
    {
      actor_relationships_path: actor_relationships_path
    }.to_json
  end

  get "/foo/bar/accepts" do |env|
    if accepts?("text/html")
      ok "html"
    elsif accepts?("text/plain")
      ok "text"
    elsif accepts?("application/ld+json", "application/activity+json", "application/json")
      ok "json"
    end
  end

  get "/foo/bar/xhr" do |env|
    if xhr?
      ok "xhr"
    else
      ok
    end
  end

  get "/foo/bar/created" do |env|
    env.created "/foobar"
  end

  get "/foo/bar/redirect" do |env|
    redirect "/foobar", 301, body: "Foo Bar"
    ok # should never get here
  end

  get "/foo/bar/sanitize" do |env|
    s "<body>Foo Bar</body>"
  end

  get "/foo/bar/pluralize" do |env|
    count = env.params.query["count"].to_i
    noun = env.params.query["noun"]
    pluralize(count, noun)
  end

  get "/foo/bar/comma" do |env|
    String.build do |s|
      ns = env.params.query["n"].split
      ns.each_with_index do |n, i|
        s << "#{n}#{comma(ns, i)}"
      end
    end
  end

  get "/foo/bar/id" do |env|
    id
  end

  get "/foo/bar/ok" do |env|
    ok "views/index", basedir: "spec/spec_helper"
  end
end

Spectator.describe Ktistec::Controller do
  before_all do
    Ktistec.database.exec "SAVEPOINT __all__"
    FooBarController.activity = Factory.create(:activity)
    FooBarController.object = Factory.create(:object)
    FooBarController.actor = Factory.create(:actor)
  end

  after_all do
    Ktistec.database.exec "ROLLBACK"
  end

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

    let(activity_id) { FooBarController.activity.id }
    let(activity_uid) { FooBarController.activity.uid }
    let(object_id) { FooBarController.object.id }
    let(object_uid) { FooBarController.object.uid }
    let(actor_id) { FooBarController.actor.id }
    let(actor_uid) { FooBarController.actor.uid }

    it "gets the thread path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["thread_path"]).to eq("/objects/#{object_uid}/thread#object-#{object_id}")
    end

    it "gets the remote thread path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["remote_thread_path"]).to eq("/remote/objects/#{object_id}/thread#object-#{object_id}")
    end

    it "gets the anchor" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["anchor"]).to eq("object-#{object_id}")
    end

    it "gets the remote activity path" do
      get "/foo/bar/helpers/activities"
      expect(JSON.parse(response.body)["remote_activity_path"]).to eq("/remote/activities/#{activity_id}")
      get "/foo/bar/helpers/activities/999999"
      expect(JSON.parse(response.body)["remote_activity_path"]).to eq("/remote/activities/999999")
    end

    it "gets the activity path" do
      get "/foo/bar/helpers/activities"
      expect(JSON.parse(response.body)["activity_path"]).to eq("/activities/#{activity_uid}")
      get "/foo/bar/helpers/activities/foo_bar"
      expect(JSON.parse(response.body)["activity_path"]).to eq("/activities/foo_bar")
    end

    it "gets the remote object path" do
      get "/foo/bar/helpers/objects"
      expect(JSON.parse(response.body)["remote_object_path"]).to eq("/remote/objects/#{object_id}")
      get "/foo/bar/helpers/objects/999999"
      expect(JSON.parse(response.body)["remote_object_path"]).to eq("/remote/objects/999999")
    end

    it "gets the object path" do
      get "/foo/bar/helpers/objects"
      expect(JSON.parse(response.body)["object_path"]).to eq("/objects/#{object_uid}")
      get "/foo/bar/helpers/objects/foo_bar"
      expect(JSON.parse(response.body)["object_path"]).to eq("/objects/foo_bar")
    end

    it "gets the remote actor path" do
      get "/foo/bar/helpers/actors"
      expect(JSON.parse(response.body)["remote_actor_path"]).to eq("/remote/actors/#{actor_id}")
      get "/foo/bar/helpers/actors/by-id/999999"
      expect(JSON.parse(response.body)["remote_actor_path"]).to eq("/remote/actors/999999")
    end

    it "gets the actor path" do
      get "/foo/bar/helpers/actors"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/#{actor_uid}")
      get "/foo/bar/helpers/actors/by-username/foo_bar"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/foo_bar")
    end

    it "gets the actor relationships path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(JSON.parse(response.body)["actor_relationships_path"]).to eq("/actors/foo_bar/helping")
    end
  end

  describe "get /foo/bar/accepts" do
    it "responds with html" do
      get "/foo/bar/accepts", HTTP::Headers{"Accept" => "text/html"}
      expect(response.headers["Content-Type"]).to eq("text/html")
      expect(XML.parse_html(response.body).xpath_string("string(//h1)") ).to eq("html")
    end

    it "responds with text" do
      get "/foo/bar/accepts", HTTP::Headers{"Accept" => "text/plain"}
      expect(response.headers["Content-Type"]).to eq("text/plain")
      expect(response.body).to eq("text")
    end

    it "responds with json" do
      get "/foo/bar/accepts", HTTP::Headers{"Accept" => %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|}
      expect(response.headers["Content-Type"]).to eq(%q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|)
      expect(JSON.parse(response.body)["msg"]).to eq("json")
    end

    it "responds with json" do
      get "/foo/bar/accepts", HTTP::Headers{"Accept" => "application/activity+json"}
      expect(response.headers["Content-Type"]).to eq("application/activity+json")
      expect(JSON.parse(response.body)["msg"]).to eq("json")
    end

    it "responds with json" do
      get "/foo/bar/accepts", HTTP::Headers{"Accept" => "application/json"}
      expect(response.headers["Content-Type"]).to eq("application/json")
      expect(JSON.parse(response.body)["msg"]).to eq("json")
    end
  end

  describe "get /foo/bar/xhr" do
    it "responds with xhr" do
      get "/foo/bar/xhr", HTTP::Headers{"Accept" => "text/html", "X-Requested-With" => "XMLHttpRequest"}
      expect(XML.parse_html(response.body).xpath_string("string(//h1)") ).to eq("xhr")
    end

    it "does not respond with xhr" do
      get "/foo/bar/xhr", HTTP::Headers{"Accept" => "text/html"}
      expect(XML.parse_html(response.body).xpath_string("string(//h1)") ).not_to eq("xhr")
    end
  end

  describe "get /foo/bar/created" do
    it "redirects with 302" do
      get "/foo/bar/created", HTTP::Headers{"Accept" => "text/html"}
      expect(response.status_code).to eq(302)
    end

    it "redirects with 201" do
      get "/foo/bar/created", HTTP::Headers{"Accept" => "text/html", "X-Requested-With" => "XMLHttpRequest"}
      expect(response.status_code).to eq(201)
    end

    it "redirects with 201" do
      get "/foo/bar/created", HTTP::Headers{"Accept" => "application/json"}
      expect(response.status_code).to eq(201)
    end
  end

  describe "get /foo/bar/redirect" do
    it "redirects with 301" do
      get "/foo/bar/redirect"
      expect(response.status_code).to eq(301)
    end

    it "sets the location header" do
      get "/foo/bar/redirect"
      expect(response.headers["Location"]).to eq("/foobar")
    end

    it "includes the body" do
      get "/foo/bar/redirect"
      expect(response.body).to eq("Foo Bar")
    end
  end

  describe "/foo/bar/sanitize" do
    it "sanitizes HTML" do
      get "/foo/bar/sanitize"
      expect(response.body).to eq("Foo Bar")
    end
  end

  describe "/foo/bar/pluralize" do
    it "pluralizes the noun" do
      get "/foo/bar/pluralize?count=0&noun=fox"
      expect(response.body).to eq("fox")
    end

    it "pluralizes the noun" do
      get "/foo/bar/pluralize?count=1&noun=fox"
      expect(response.body).to eq("1 fox")
    end

    it "pluralizes the noun" do
      get "/foo/bar/pluralize?count=2&noun=fox"
      expect(response.body).to eq("2 foxes")
    end
  end

  describe "/foo/bar/comma" do
    it "adds a comma where appropriate" do
      get "/foo/bar/comma?n=1 2 3 4 5 6"
      expect(response.body).to eq("1,2,3,4,5,6")
    end
  end

  describe "/foo/bar/id" do
    it "generates a URL-safe random string" do
      get "/foo/bar/id"
      expect(response.body).to match(/^[a-zA-Z0-9_-]+$/)
    end
  end

  describe "/foo/bar/ok" do
    it "responds with html" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "text/html"}
      expect(XML.parse_html(response.body).xpath_nodes("//cite").first).to eq("html")
    end

    it "responds with text" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "text/plain"}
      expect(response.body.strip).to eq("text")
    end

    it "responds with json" do
      get "/foo/bar/ok"
      expect(JSON.parse(response.body)).to eq("json")
    end

    it "sets the content type" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|}
      expect(response.headers["Content-Type"]).to eq(%q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|)
    end

    it "sets the content type" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/activity+json"}
      expect(response.headers["Content-Type"]).to eq("application/activity+json")
    end

    it "sets the content type" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/json"}
      expect(response.headers["Content-Type"]).to eq("application/json")
    end
  end
end
