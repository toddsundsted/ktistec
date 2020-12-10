require "../../src/framework/rewrite"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/actors/foobar"]

  get "/actors/foobar" do |env|
    "gotcha"
  end
end

Spectator.describe Ktistec::Rewrite do
  describe "get /@foobar" do
    it "rewrites the request" do
      get "/@foobar"
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("gotcha")
    end
  end

  describe "get /%40foobar" do
    it "rewrites the request" do
      get "/%40foobar"
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("gotcha")
    end
  end
end
