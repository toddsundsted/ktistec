require "../spec_helper"

class FooBarController
  include Balloon::Controller

  get "/foo/bar/host" do |env|
    {host: host}.to_json
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
end
