require "../../src/views/view_helper"

require "../spec_helper/controller"
require "../spec_helper/factory"

class FooBarController
  include Ktistec::Controller

  skip_auth [
    "/foo/bar/id_param/:id",
    "/foo/bar/iri_param/:id",
  ]

  get "/foo/bar/id_param/:id" do |env|
    id_param(env).to_s
  end

  get "/foo/bar/iri_param/:id" do |env|
    iri_param(env, "/foo/bar").to_s
  end
end

Spectator.describe FooBarController do
  describe "GET /foo/bar/id_param/:id" do
    it "is not successful for non-numeric parameters" do
      get "/foo/bar/id_param/five"
      expect(response.status_code).to eq(400)
    end

    it "is successful for numeric parameters" do
      get "/foo/bar/id_param/5"
      expect(response.status_code).to eq(200)
    end

    it "it returns the id of the resource" do
      get "/foo/bar/id_param/5"
      expect(response.body).to eq("5")
    end
  end

  describe "GET /foo/bar/iri_param/:id" do
    it "is not successful for invalid parameters" do
      get "/foo/bar/iri_param/+"
      expect(response.status_code).to eq(400)
    end

    it "is successful for valid parameters" do
      get "/foo/bar/iri_param/000"
      expect(response.status_code).to eq(200)
    end

    it "it returns the IRI of the resource" do
      get "/foo/bar/iri_param/000"
      expect(response.body).to eq("https://test.test/foo/bar/000")
    end
  end
end
