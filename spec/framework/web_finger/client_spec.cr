require "spectator"

require "../../../src/framework/web_finger"

require "../../spec_helper/base"
require "../../spec_helper/network"

# Stubs the host-meta lookup. returns a non-standard webfinger
# template so tests don't accidentally exercise the fall-back template
# defined in `src/framework/web_finger/client.cr`.
private def stub_host_meta(host)
  body = <<-XML
    <?xml version="1.0"?>
    <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
      <Link rel="lrdd" type="application/xrd+xml" template="https://#{host}/webfinger?r={uri}"/>
    </XRD>
    XML
  HTTP::Client.cache.set_response(
    "https://#{host}/.well-known/host-meta",
    HTTP::Client::Response.new(
      200,
      headers: HTTP::Headers{"Content-Type" => "application/xrd+xml"},
      body: body,
    ),
  )
end

Spectator.describe Ktistec::WebFinger::Client do
  setup_spec

  describe ".query" do
    it "raises an error if host doesn't exist" do
      expect_raises(Ktistec::WebFinger::NotFoundError) do
        Ktistec::WebFinger::Client.query("acct:foobar@socket-addrinfo-error.com")
      end
    end

    it "raises an error if client can't connect to host" do
      expect_raises(Ktistec::WebFinger::NotFoundError) do
        Ktistec::WebFinger::Client.query("acct:foobar@socket-connect-error.com")
      end
    end

    it "raises an error if account doesn't exist" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(404),
      )
      expect_raises(Ktistec::WebFinger::NotFoundError) do
        Ktistec::WebFinger::Client.query("acct:foobar@example.com")
      end
    end

    it "raises an error if request fails for any reason" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(500),
      )
      expect_raises(Ktistec::WebFinger::Error) do
        Ktistec::WebFinger::Client.query("acct:foobar@example.com")
      end
    end

    it "returns a result for an application/jrd+json response" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/jrd+json"},
          body: "{}",
        ),
      )
      expect(Ktistec::WebFinger::Client.query("acct:foobar@example.com")).to be_a(Ktistec::WebFinger::Result)
    end

    it "returns a result for an application/xrd+xml response" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/xrd+xml"},
          body: %(<?xml version="1.0"?><XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"/>),
        ),
      )
      expect(Ktistec::WebFinger::Client.query("acct:foobar@example.com")).to be_a(Ktistec::WebFinger::Result)
    end

    it "returns a result for a response without a content type" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "{}"),
      )
      expect(Ktistec::WebFinger::Client.query("acct:foobar@example.com")).to be_a(Ktistec::WebFinger::Result)
    end

    it "raises an error if JSON is bad" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/jrd+json"},
          body: "<>",
        ),
      )
      expect_raises(Ktistec::WebFinger::ResultError) do
        Ktistec::WebFinger::Client.query("acct:foobar@example.com")
      end
    end

    it "raises an error if XML is bad" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/xrd+xml"},
          body: "{}",
        ),
      )
      expect_raises(Ktistec::WebFinger::ResultError) do
        Ktistec::WebFinger::Client.query("acct:foobar@example.com")
      end
    end

    it "follows redirects" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          302,
          headers: HTTP::Headers{"Location" => "https://elsewhere.com/"},
          body: "",
        ),
      )
      HTTP::Client.cache.set_response(
        "https://elsewhere.com/",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::WebFinger::Client.query("acct:foobar@example.com")
      expect(HTTP::Client.requests).to have("GET https://elsewhere.com/")
    end

    it "requests the webfinger URL with the account as a query parameter" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=acct%3Afoobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::WebFinger::Client.query("acct:foobar@example.com")
      expect(HTTP::Client.requests).to have("GET https://example.com/webfinger?r=acct%3Afoobar%40example.com")
    end

    it "supports a missing 'acct' URI scheme" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=foobar%40example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::WebFinger::Client.query("foobar@example.com")
      expect(HTTP::Client.requests).to have("GET https://example.com/webfinger?r=foobar%40example.com")
    end

    it "supports the HTTPS URI scheme with a path" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=https%3A%2F%2Fexample.com%2F%40foobar",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::WebFinger::Client.query("https://example.com/@foobar")
      expect(HTTP::Client.requests).to have("GET https://example.com/webfinger?r=https%3A%2F%2Fexample.com%2F%40foobar")
    end

    it "supports a domain name" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=example.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::WebFinger::Client.query("example.com")
      expect(HTTP::Client.requests).to have("GET https://example.com/webfinger?r=example.com")
    end

    it "supports the HTTPS URI scheme without a path" do
      stub_host_meta("example.com")
      HTTP::Client.cache.set_response(
        "https://example.com/webfinger?r=https%3A%2F%2Fexample.com",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::WebFinger::Client.query("https://example.com")
      expect(HTTP::Client.requests).to have("GET https://example.com/webfinger?r=https%3A%2F%2Fexample.com")
    end
  end
end
