require "../../../src/framework/ext/kemal"
require "../../../src/framework/controller"

require "../../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/only", "/foo/bar/one", "/foo/bar/two", "/foo/bar/three"], GET

  get "/foo/bar/only" do |env|
    env.request.path
  end

  get "/foo/bar/one", "/foo/bar/two", "/foo/bar/three" do |env|
    env.request.path
  end
end

Spectator.describe "routes" do
  setup_spec

  it "registers a single path" do
    get "/foo/bar/only"
    expect(response.status_code).to eq(200)
    expect(response.body).to eq("/foo/bar/only")
  end

  it "registers the first path" do
    get "/foo/bar/one"
    expect(response.status_code).to eq(200)
    expect(response.body).to eq("/foo/bar/one")
  end

  it "registers the second path" do
    get "/foo/bar/two"
    expect(response.status_code).to eq(200)
    expect(response.body).to eq("/foo/bar/two")
  end

  it "registers the remaining paths" do
    get "/foo/bar/three"
    expect(response.status_code).to eq(200)
    expect(response.body).to eq("/foo/bar/three")
  end
end
