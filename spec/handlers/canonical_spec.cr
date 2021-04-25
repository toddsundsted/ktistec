require "../../src/handlers/canonical"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/secret", "/foo/bar/secret/*"], GET

  get "/foo/bar/secret" do |env|
  end

  get "/foo/bar/secret/:segment" do |env|
    env.params.url["segment"]
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

      context "and a request with a segment suffix" do
        sample ["thread"] do |segment|
          it "returns 200" do
            get "/does/not/exist/#{segment}", ACCEPT_HTML
            expect(response.status_code).to eq(200)
            expect(response.body).to eq(segment)
          end

          it "returns 301" do
            get "/foo/bar/secret/#{segment}", ACCEPT_HTML
            expect(response.status_code).to eq(301)
            expect(response.headers["Location"]).to eq("/does/not/exist/#{segment}")
          end
        end
      end
    end
  end
end
