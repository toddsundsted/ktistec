require "../../src/framework/method"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/delete/:id"], DELETE, POST

  delete "/foo/bar/delete/:id" do |env|
    env.response.status_code = 410
    env.params.url["id"]
  end

  post "/foo/bar/delete/:id" do |env|
    env.response.status_code = 202
    env.params.url["id"]
  end
end

Spectator.describe Ktistec::Method do
  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}

  describe "post /foo/bar/delete/:id" do
    it "invokes the delete action" do
      post "/foo/bar/delete/11", HTML_HEADERS, "_method=delete"
      expect(response.status_code).to eq(410)
      expect(response.body).to eq("11")
    end

    it "invokes the post action" do
      post "/foo/bar/delete/13", HTML_HEADERS, ""
      expect(response.status_code).to eq(202)
      expect(response.body).to eq("13")
    end
  end
end
