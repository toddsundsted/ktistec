require "spectator"

require "../../../src/framework/host_meta"

require "../../spec_helper/base"
require "../../spec_helper/network"

Spectator.describe Ktistec::HostMeta::Client do
  setup_spec

  describe ".query" do
    it "raises an error if host doesn't exist" do
      expect_raises(Ktistec::HostMeta::NotFoundError) do
        Ktistec::HostMeta::Client.query("socket-addrinfo-error.com")
      end
    end

    it "raises an error if client can't connect to host" do
      expect_raises(Ktistec::HostMeta::NotFoundError) do
        Ktistec::HostMeta::Client.query("socket-connect-error.com")
      end
    end

    it "raises an error if URL doesn't exist" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(404),
      )
      expect_raises(Ktistec::HostMeta::NotFoundError) do
        Ktistec::HostMeta::Client.query("example.com")
      end
    end

    it "raises an error if request fails for any reason" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(500),
      )
      expect_raises(Ktistec::HostMeta::Error) do
        Ktistec::HostMeta::Client.query("example.com")
      end
    end

    it "returns a result for an application/jrd+json response" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/jrd+json"},
          body: "{}",
        ),
      )
      expect(Ktistec::HostMeta::Client.query("example.com")).to be_a(Ktistec::HostMeta::Result)
    end

    it "returns a result for an application/xrd+xml response" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/xrd+xml"},
          body: %(<?xml version="1.0"?><XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"/>),
        ),
      )
      expect(Ktistec::HostMeta::Client.query("example.com")).to be_a(Ktistec::HostMeta::Result)
    end

    it "returns a result for a response without a content type" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "{}"),
      )
      expect(Ktistec::HostMeta::Client.query("example.com")).to be_a(Ktistec::HostMeta::Result)
    end

    it "raises an error if JSON is bad" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/jrd+json"},
          body: "<>",
        ),
      )
      expect_raises(Ktistec::HostMeta::ResultError) do
        Ktistec::HostMeta::Client.query("example.com")
      end
    end

    it "raises an error if XML is bad" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers{"Content-Type" => "application/xrd+xml"},
          body: "{}",
        ),
      )
      expect_raises(Ktistec::HostMeta::ResultError) do
        Ktistec::HostMeta::Client.query("example.com")
      end
    end

    it "follows redirects" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
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
      Ktistec::HostMeta::Client.query("example.com")
      expect(HTTP::Client.requests).to have("GET https://elsewhere.com/")
    end

    it "requests the well-known host-meta URL" do
      HTTP::Client.cache.set_response(
        "https://example.com/.well-known/host-meta",
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "<XRD/>"),
      )
      Ktistec::HostMeta::Client.query("example.com")
      expect(HTTP::Client.requests).to have("GET https://example.com/.well-known/host-meta")
    end
  end
end
