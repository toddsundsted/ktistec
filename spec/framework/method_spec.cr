require "../spec_helper"

class FooBarController
  include Balloon::Controller

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

Spectator.describe Balloon::Method do
  describe "post /foo/bar/delete/:id" do
    it "invokes the delete action" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      post "/foo/bar/delete/11", headers, "_method=delete"
      expect(response.status_code).to eq(410)
      expect(response.body).to eq("11")
    end

    it "invokes the post action" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
      post "/foo/bar/delete/13", headers, ""
      expect(response.status_code).to eq(202)
      expect(response.body).to eq("13")
    end
  end
end
