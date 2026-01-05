require "../../src/framework/controller"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth [
    "/foo/bar/accepts",
    "/foo/bar/turbo-streams/:target/:operation",
    "/foo/bar/turbo-streams/:target/:operation/:method",
    "/foo/bar/turbo-stream",
    "/foo/bar/turbo-frame",
    "/foo/bar/redirect",
    "/foo/bar/created",
    "/foo/bar/ok"
  ]

  get "/foo/bar/accepts" do |env|  # ameba:disable Lint/UnusedArgument
    if accepts?("text/html")
      ok "html"
    elsif accepts?("text/plain")
      ok "text"
    elsif accepts?("application/ld+json", "application/activity+json", "application/json")
      ok "json"
    end
  end

  get "/foo/bar/turbo-streams/:target/:operation" do |env|
    ok "turbo-streams", _target: env.params.url["target"], _operation: env.params.url["operation"]
  end

  get "/foo/bar/turbo-streams/:target/:operation/:method" do |env|
    ok "turbo-streams", _target: env.params.url["target"], _operation: env.params.url["operation"], _method: env.params.url["method"]
  end

  get "/foo/bar/turbo-stream" do |env|  # ameba:disable Lint/UnusedArgument
    if accepts_turbo_stream?
      ok "turbo-stream", _operation: "replace", _target: "foobar"
    else
      ok
    end
  end

  get "/foo/bar/turbo-frame" do |env|  # ameba:disable Lint/UnusedArgument
    if in_turbo_frame?
      ok "turbo-frame"
    else
      ok
    end
  end

  get "/foo/bar/redirect" do |env|  # ameba:disable Lint/UnusedArgument
    redirect "/foobar", 301
  end

  get "/foo/bar/created" do |env|  # ameba:disable Lint/UnusedArgument
    created "/foobar", "body"
  end

  get "/foo/bar/ok" do |env|
    ok "views/index", _basedir: "spec/spec_helper", env: env
  end
end

Spectator.describe Ktistec::Controller do
  describe "GET /foo/bar/accepts" do
    it "responds with html" do
      get "/foo/bar/accepts", HTTP::Headers{"Accept" => "text/html"}
      expect(response.headers["Content-Type"]).to eq("text/html")
      expect(XML.parse_html(response.body).xpath_string("string(//h1)")).to eq("html")
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

  describe "GET /foo/bar/turbo-streams/:target/:operation" do
    it "responds with turbo-streams" do
      get "/foo/bar/turbo-streams/foo-bar/append", HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html"}
      expect(XML.parse_html(response.body).xpath_string("string(//turbo-stream[@target='foo-bar'][@action='append'][not(@method)]/template//h1)")).to eq("turbo-streams")
    end
  end

  describe "GET /foo/bar/turbo-streams/:target/:operation/:method" do
    it "responds with turbo-streams" do
      get "/foo/bar/turbo-streams/foo-bar/append/before", HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html"}
      expect(XML.parse_html(response.body).xpath_string("string(//turbo-stream[@target='foo-bar'][@action='append'][@method='before']/template//h1)")).to eq("turbo-streams")
    end
  end

  describe "GET /foo/bar/turbo-stream" do
    it "responds with turbo-stream" do
      get "/foo/bar/turbo-stream", HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html"}
      expect(XML.parse_html(response.body).xpath_string("string(//h1)")).to eq("turbo-stream")
    end

    it "does not respond with turbo-stream" do
      get "/foo/bar/turbo-stream", HTTP::Headers{"Accept" => "text/html"}
      expect(XML.parse_html(response.body).xpath_string("string(//h1)")).not_to eq("turbo-stream")
    end
  end

  describe "POST /foo/bar/turbo-frame" do
    it "responds with turbo-frame" do
      get "/foo/bar/turbo-frame", HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "foo-bar"}
      expect(XML.parse_html(response.body).xpath_string("string(//h1)")).to eq("turbo-frame")
    end

    it "does not respond with turbo-frame" do
      get "/foo/bar/turbo-frame", HTTP::Headers{"Accept" => "text/html"}
      expect(XML.parse_html(response.body).xpath_string("string(//h1)")).not_to eq("turbo-frame")
    end
  end

  describe "GET /foo/bar/redirect" do
    it "redirects with 301" do
      get "/foo/bar/redirect"
      expect(response.status_code).to eq(301)
    end

    it "sets the location header" do
      get "/foo/bar/redirect"
      expect(response.headers["Location"]).to eq("/foobar")
    end
  end

  describe "GET /foo/bar/created" do
    it "responds with 201" do
      get "/foo/bar/created"
      expect(response.status_code).to eq(201)
    end

    it "sets the location header" do
      get "/foo/bar/created"
      expect(response.headers["Location"]).to eq("/foobar")
    end

    it "includes the body" do
      get "/foo/bar/created", HTTP::Headers{"Accept" => "text/plain"}
      expect(response.body).to eq("body")
    end
  end

  describe "GET /foo/bar/ok" do
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

    it "responds with html by default" do
      get "/foo/bar/ok"
      expect(XML.parse_html(response.body).xpath_nodes("//cite").first).to eq("html")
    end

    it "prefers html" do
      get "/foo/bar/ok", HTTP::Headers{"Accept" => "application/json, text/plain, text/html"}
      expect(XML.parse_html(response.body).xpath_nodes("//cite").first).to eq("html")
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
