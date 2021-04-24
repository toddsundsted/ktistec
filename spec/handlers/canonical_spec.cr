require "../../src/handlers/canonical"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/secret"]

  get "/foo/bar/secret" do |env|
  end
end

Spectator.describe Ktistec::Handler::Canonical do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}
  XHR = HTTP::Headers{"Accept" => "text/html", "X-Requested-With" => "XMLHttpRequest"}

  describe "get /does/not/exist" do
    it "returns 404" do
      get "/does/not/exist", ACCEPT_HTML
      expect(response.status_code).to eq(404)
    end

    it "returns 200" do
      get "/foo/bar/secret", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    context "given a canonical mapping" do
      before_each do
        Relationship::Content::Canonical.new(
          from_iri: "/does/not/exist",
          to_iri: "/foo/bar/secret"
        ).save
      end

      it "returns 200" do
        get "/does/not/exist", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "returns 301" do
        get "/foo/bar/secret", ACCEPT_HTML
        expect(response.status_code).to eq(301)
      end

      context "and a request for JSON" do
        it "does not redirect" do
          get "/foo/bar/secret", ACCEPT_JSON
          expect(response.status_code).to eq(200)
        end
      end

      context "and an XHR request" do
        it "does not redirect" do
          get "/foo/bar/secret", XHR
          expect(response.status_code).to eq(200)
        end
      end
    end
  end
end
