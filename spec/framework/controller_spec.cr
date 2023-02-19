require "../../src/framework/controller"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth [
    "/foo/bar/host",
    "/foo/bar/accepts",
    "/foo/bar/created",
    "/foo/bar/redirect",
    "/foo/bar/ok"
  ]

  get "/foo/bar/host" do |env|
    {host: host}.to_json
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

  get "/foo/bar/created" do |env|
    env.created "/foobar"
  end

  get "/foo/bar/redirect" do |env|
    redirect "/foobar", 301, body: "Foo Bar"
    ok # should never get here
  end

  get "/foo/bar/ok" do |env|
    ok "views/index", basedir: "spec/spec_helper"
  end
end

Spectator.describe Ktistec::Controller do
  describe "get /foo/bar/host" do
    it "gets the host" do
      get "/foo/bar/host"
      expect(JSON.parse(response.body)["host"]).to eq("https://test.test")
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

  describe "get /foo/bar/created" do
    it "redirects with 302" do
      get "/foo/bar/created", HTTP::Headers{"Accept" => "text/html"}
      expect(response.status_code).to eq(302)
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

  describe "/foo/bar/ok" do
    it "responds with json" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/json"}
      expect(JSON.parse(response.body)).to eq("json")
    end

    it "responds with text" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "text/plain"}
      expect(response.body.strip).to eq("text")
    end

    it "responds with html" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "text/html"}
      expect(XML.parse_html(response.body).xpath_nodes("//cite").first).to eq("html")
    end

    it "responds with json by default" do
      get "/foo/bar/ok"
      expect(JSON.parse(response.body)).to eq("json")
    end

    it "prefers json" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/json, text/plain, text/html"}
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
