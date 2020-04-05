require "../spec_helper"

class FooBarController
  include Balloon::Controller

  get "/foo/bar/host" do |env|
    {host: host}.to_json
  end

  get "/foo/bar/accept" do |env|
    if accepts?("text/html")
      "html"
    elsif accepts?("application/json")
      "json"
    end
  end
end

Spectator.describe Balloon::Controller do
  describe "get /foo/bar/host" do
    it "gets the host" do
      get "/foo/bar/host"
      expect(response.status_code).to eq(200)
      expect(JSON.parse(response.body)["host"]).to eq("https://test.test")
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
end
