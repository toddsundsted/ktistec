require "../../src/framework/method"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/delete"], DELETE, POST

  delete "/foo/bar/delete" do |env|
    env.response.status_code = 410
    "delete"
  end

  post "/foo/bar/delete" do |env|
    env.response.status_code = 202
    "post"
  end
end

Spectator.describe Ktistec::Method do
  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}

  describe "post /foo/bar/delete" do
    it "invokes the delete action" do
      post "/foo/bar/delete", HTML_HEADERS, "_method=delete"
      expect(response.status_code).to eq(410)
      expect(response.body).to eq("delete")
    end

    it "invokes the post action" do
      post "/foo/bar/delete", HTML_HEADERS, ""
      expect(response.status_code).to eq(202)
      expect(response.body).to eq("post")
    end
  end
end
