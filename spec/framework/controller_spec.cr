require "../spec_helper"

class FooBarController
  include Balloon::Controller

  skip_auth ["/foo/bar/helpers", "/foo/bar/helpers/:username/:relationship", "/foo/bar/accept", "/foo/bar/escape"]

  get "/foo/bar/helpers" do |env|
    {
      host: host,
      home_path: home_path,
      sessions_path: sessions_path
    }.to_json
  end

  get "/foo/bar/helpers/:username/:relationship" do |env|
    {
      actor_path: actor_path,
      actor_relationships_path: actor_relationships_path
    }.to_json
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
end

Spectator.describe Balloon::Controller do
  describe "get /foo/bar/helpers" do
    it "gets the host" do
      get "/foo/bar/helpers"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["host"]).to eq("https://test.test")
    end

    it "gets the home path" do
      get "/foo/bar/helpers"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["home_path"]).to eq("/")
    end

    it "gets the sessions path" do
      get "/foo/bar/helpers"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["sessions_path"]).to eq("/sessions")
    end

    it "gets the actor path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/foo_bar")
    end

    it "gets the actor relationships path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["actor_relationships_path"]).to eq("/actors/foo_bar/helping")
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
end
