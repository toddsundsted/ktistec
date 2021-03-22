require "../../src/framework/controller"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

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
    "/foo/bar/helpers/actors/by-id/:id",
    "/foo/bar/helpers/actors/by-username/:username",
    "/foo/bar/helpers/:username/:relationship",
    "/foo/bar/helpers/tag",
    "/foo/bar/paginate",
    "/foo/bar/accept",
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
      remote_thread_path: remote_thread_path(OBJECT),
      anchor: anchor(OBJECT)
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

  get "/foo/bar/helpers/tag" do |env|
    form1 = tag :form, id: 1, class: "basic" do |html|
      html << tag :input, type: "hidden", value: "secret"
      html << tag :input, type: "submit"
    end
    form2 = tag :form, id: 1, class: "basic" do
      String.build do |io|
        io << %q|<input type="hidden" value="secret">|
        io << %q|<input type="submit">|
      end
    end
    <<-HTML
    <div id="1">#{tag div}</div>
    <div id="2.1">#{tag div, "foobar"}</div>
    <div id="2.2">#{tag div, "foo", "bar"}</div>
    <div id="2.3">#{tag div, "foo" + "bar"}</div>
    <div id="2.4">#{tag div, "f" + "oo", "b" + "ar"}</div>
    <div id="3.1">#{tag div, tag span}</div>
    <div id="3.2">#{tag div, tag(span, "foobar")}</div>
    <div id="4">#{tag div, tag(span, id: 5, class: "quux"), style: "foobar"}</div>
    <div id="5.1">#{tag div do |h| h << tag span end}</div>
    <div id="5.2">#{tag div do |h| h << tag span, "foobar" end}</div>
    <div id="6.1">#{form1}</div>
    <div id="6.2">#{form2}</div>
    <div id="7">#{activity_button "Foo Bar", "outbox url", "object iri", type: "FooBar", form_class: "foobar", button_class: "barfoo"}</div>
    <div id="8">#{activity_button "outbox url", "object iri", "FooBar" { |html| html << tag div, "Foo Bar" } }</div>
    HTML
  end

  get "/foo/bar/paginate" do |env|
    page = env.params.query["page"]?.try(&.to_i) || 1
    size = env.params.query["size"]?.try(&.to_i) || 10
    results = Ktistec::Util::PaginatedArray(Int32).new
    (0..9).to_a[(page - 1) * size, size].each { |v| results << v }
    results.more = (page) * size < 10
    paginate(results, env)
  end

  get "/foo/bar/accept" do |env|
    if accepts?("text/html")
      ok "html"
    elsif accepts?("text/plain")
      ok "text"
    elsif accepts?("application/json")
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

    let(oid) { FooBarController::OBJECT.id }

    it "gets the remote thread path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["remote_thread_path"]).to eq("/remote/objects/#{oid}/thread#object-#{oid}")
    end

    it "gets the anchor" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["anchor"]).to eq("object-#{oid}")
    end

    it "gets the remote activity path" do
      get "/foo/bar/helpers/activities"
      expect(JSON.parse(response.body)["remote_activity_path"]).to eq("/remote/activities/#{FooBarController::ACTIVITY.id}")
      get "/foo/bar/helpers/activities/999999"
      expect(JSON.parse(response.body)["remote_activity_path"]).to eq("/remote/activities/999999")
    end

    it "gets the activity path" do
      get "/foo/bar/helpers/activities"
      expect(JSON.parse(response.body)["activity_path"]).to eq("/activities/#{FooBarController::ID}")
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
      expect(JSON.parse(response.body)["object_path"]).to eq("/objects/#{FooBarController::ID}")
      get "/foo/bar/helpers/objects/foo_bar"
      expect(JSON.parse(response.body)["object_path"]).to eq("/objects/foo_bar")
    end

    it "gets the remote actor path" do
      get "/foo/bar/helpers/actors"
      expect(JSON.parse(response.body)["remote_actor_path"]).to eq("/remote/actors/#{FooBarController::ACTOR.id}")
      get "/foo/bar/helpers/actors/by-id/999999"
      expect(JSON.parse(response.body)["remote_actor_path"]).to eq("/remote/actors/999999")
    end

    it "gets the actor path" do
      get "/foo/bar/helpers/actors"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/#{FooBarController::ID}")
      get "/foo/bar/helpers/actors/by-username/foo_bar"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/foo_bar")
    end

    it "gets the actor relationships path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(JSON.parse(response.body)["actor_relationships_path"]).to eq("/actors/foo_bar/helping")
    end
  end

  describe "get /foo/bar/helpers/tag" do
    let(options) { {options: XML::SaveOptions::AS_HTML} }

    macro tag(id)
      XML.parse_html(response.body).xpath_nodes("//div[@id='{{id}}']/node()").map(&.to_xml(**options)).join
    end

    it "renders a tag" do
      get "/foo/bar/helpers/tag"
      expect(tag(1)).to eq(%Q|<div></div>|)
    end

    it "renders a tag with content" do
      get "/foo/bar/helpers/tag"
      expect(tag(2.1)).to eq(%Q|<div>foobar</div>|)
    end

    it "renders a tag with content" do
      get "/foo/bar/helpers/tag"
      expect(tag(2.2)).to eq(%Q|<div>foobar</div>|)
    end

    it "renders a tag with content" do
      get "/foo/bar/helpers/tag"
      expect(tag(2.3)).to eq(%Q|<div>foobar</div>|)
    end

    it "renders a tag with content" do
      get "/foo/bar/helpers/tag"
      expect(tag(2.4)).to eq(%Q|<div>foobar</div>|)
    end

    it "renders nested tags" do
      get "/foo/bar/helpers/tag"
      expect(tag(3.1)).to eq(%Q|<div><span></span></div>|)
    end

    it "renders nested tags" do
      get "/foo/bar/helpers/tag"
      expect(tag(3.2)).to eq(%Q|<div><span>foobar</span></div>|)
    end

    it "renders a tag with attributes" do
      get "/foo/bar/helpers/tag"
      expect(tag(4)).to eq(%Q|<div style="foobar"><span id="5" class="quux"></span></div>|)
    end

    it "renders block as content" do
      get "/foo/bar/helpers/tag"
      expect(tag(5.1)).to eq(%Q|<div><span></span></div>|)
    end

    it "renders block as content" do
      get "/foo/bar/helpers/tag"
      expect(tag(5.2)).to eq(%Q|<div><span>foobar</span></div>|)
    end

    it "renders complex form" do
      get "/foo/bar/helpers/tag"
      expect(tag(6.1)).to eq(%Q|<form id="1" class="basic"><input type="hidden" value="secret"><input type="submit"></form>|)
    end

    it "renders complex form" do
      get "/foo/bar/helpers/tag"
      expect(tag(6.2)).to eq(%Q|<form id="1" class="basic"><input type="hidden" value="secret"><input type="submit"></form>|)
    end

    it "renders a submit button" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/button[@type='submit']/text())")).to eq("Foo Bar")
    end

    it "renders a hidden input with the authenticity token" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/input[@name='authenticity_token']/@value)")).to eq("CSRF TOKEN")
    end

    it "renders a hidden input with the activity type" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/input[@name='type']/@value)")).to eq("FooBar")
    end

    it "renders a hidden input with the object iri" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/input[@name='object']/@value)")).to eq("object iri")
    end

    it "renders a form with the outbox url" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/@action)")).to eq("outbox url")
    end

    it "renders submit button with classes" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/button[@type='submit']/@class)")).to eq("ui button barfoo")
    end

    it "renders form with classes" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='7']/form/@class)")).to eq("ui form foobar")
    end

    it "renders a form with nested content" do
      get "/foo/bar/helpers/tag"
      expect(XML.parse_html(response.body).xpath_string("string(//div[@id='8']/form//div/text())")).to eq("Foo Bar")
    end
  end

  describe "get /foo/bar/paginate" do
    it "does not display pagination controls" do
      get "/foo/bar/paginate"
      expect(XML.parse_html(response.body).xpath_nodes("//a")).to be_empty
    end

    it "displays the prev link" do
      get "/foo/bar/paginate?page=2"
      expect(XML.parse_html(response.body).xpath_nodes("//a[contains(@href,'page=1')]")).not_to be_empty
    end

    it "displays the next link" do
      get "/foo/bar/paginate?size=9"
      expect(XML.parse_html(response.body).xpath_nodes("//a[contains(@href,'page=2')]")).not_to be_empty
    end
  end

  describe "get /foo/bar/accept" do
    it "responds with html" do
      get "/foo/bar/accept", HTTP::Headers{"Accept" => "text/html"}
      expect(response.headers["Content-Type"]).to eq("text/html")
      expect(XML.parse_html(response.body).xpath_string("string(//h1)") ).to eq("html")
    end

    it "responds with text" do
      get "/foo/bar/accept", HTTP::Headers{"Accept" => "text/plain"}
      expect(response.headers["Content-Type"]).to eq("text/plain")
      expect(response.body).to eq("text")
    end

    it "responds with json" do
      get "/foo/bar/accept", HTTP::Headers{"Accept" => "application/json"}
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
      expect(XML.parse_html(response.body).xpath_nodes("//cite").first.text).to eq("html")
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
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/activity+json"}
      expect(response.headers["Content-Type"]).to eq("application/activity+json")
    end

    it "sets the content type" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/json"}
      expect(response.headers["Content-Type"]).to eq("application/json")
    end
  end
end
