require "../spec_helper"

class FooBarController
  include Balloon::Controller

  skip_auth ["/foo/bar/helpers", "/foo/bar/helpers/:username/:relationship", "/foo/bar/paginate", "/foo/bar/accept", "/foo/bar/escape", "/foo/bar/sanitize"]

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

  get "/foo/bar/paginate" do |env|
    page = env.params.query["page"]?.try(&.to_i) || 0
    size = env.params.query["size"]?.try(&.to_i) || 10
    results = Balloon::Util::PaginatedArray(Int32).new
    (0..9).to_a[page * size, size].each { |v| results << v }
    results.more = (page + 1) * size < 10
    paginate(results, env)
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

  get "/foo/bar/sanitize" do |env|
    s "<body>Foo Bar</body>"
  end
end

Spectator.describe Balloon::Controller do
  describe "get /foo/bar/helpers" do
    it "gets the host" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["host"]).to eq("https://test.test")
    end

    it "gets the home path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["home_path"]).to eq("/")
    end

    it "gets the sessions path" do
      get "/foo/bar/helpers"
      expect(JSON.parse(response.body)["sessions_path"]).to eq("/sessions")
    end

    it "gets the actor path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(JSON.parse(response.body)["actor_path"]).to eq("/actors/foo_bar")
    end

    it "gets the actor relationships path" do
      get "/foo/bar/helpers/foo_bar/helping"
      expect(JSON.parse(response.body)["actor_relationships_path"]).to eq("/actors/foo_bar/helping")
    end
  end

  describe "get /foo/bar/paginate" do
    it "does not display pagination controls" do
      get "/foo/bar/paginate"
      expect(XML.parse_html(response.body).xpath_nodes("//a")).to be_empty
    end

    it "displays the prev link" do
      get "/foo/bar/paginate?page=1"
      expect(XML.parse_html(response.body).xpath_nodes("//a[contains(text(),'Prev')]")).not_to be_empty
    end

    it "displays the next link" do
      get "/foo/bar/paginate?size=9"
      expect(XML.parse_html(response.body).xpath_nodes("//a[contains(text(),'Next')]")).not_to be_empty
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

  describe "/foo/bar/sanitize" do
    it "sanitizes HTML" do
      get "/foo/bar/sanitize"
      expect(response.body).to eq("<p>Foo Bar</p>")
    end
  end
end
