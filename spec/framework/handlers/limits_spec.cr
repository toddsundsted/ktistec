require "../../../src/framework/handlers/limits"

require "../../spec_helper/controller"
require "../../spec_helper/factory"

class LimitsNextHandler < Kemal::Handler
  getter? called = false
  getter received_bytes : Int32? = nil

  def call(env)
    @called = true
    @received_bytes = env.request.body.try(&.gets_to_end.bytesize)
  end
end

Spectator.describe Ktistec::Limits do
  setup_spec

  INBOX_LIMIT         = Ktistec::Limits::INBOX_LIMIT
  AUTHENTICATED_LIMIT = Ktistec::Limits::AUTHENTICATED_LIMIT
  ANONYMOUS_LIMIT     = Ktistec::Limits::ANONYMOUS_LIMIT

  let(next_handler) { LimitsNextHandler.new }

  subject { described_class.new.tap(&.next = next_handler) }

  let(path) { "/foo/bar" }
  let(accept) { "application/json" }
  let(body_size) { ANONYMOUS_LIMIT }
  let(content_length) { nil }

  let(response) do
    headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => accept}
    body = body_size.try { |size| IO::Memory.new("a" * size) }
    content_length.try { |length| headers["Content-Length"] = length.to_s }
    io = IO::Memory.new
    context = HTTP::Server::Context.new(HTTP::Request.new("POST", path, headers, body), HTTP::Server::Response.new(io))
    subject.call(context)
    context.response.close
    HTTP::Client::Response.from_io(io.rewind, decompress: false)
  end

  it "allows a body up to the anonymous limit" do
    response
    expect(next_handler.received_bytes).to eq(ANONYMOUS_LIMIT)
  end

  context "without a body" do
    let(body_size) { nil }

    it "passes the request on to the next handler" do
      response
      expect(next_handler.called?).to be_true
    end
  end

  context "with a body over the anonymous limit" do
    let(body_size) { ANONYMOUS_LIMIT + 1 }

    it "refuses the request" do
      expect(response.status_code).to eq(413)
    end

    it "does not pass the request on to the next handler" do
      response
      expect(next_handler.called?).to be_false
    end

    context "and JSON accepted" do
      pre_condition { expect(accept).to eq("application/json") }

      it "refuses with an error" do
        expect(JSON.parse(response.body)["msg"]).to eq("payload too large")
      end
    end

    context "and HTML accepted" do
      let(accept) { "text/html" }

      it "refuses with an error" do
        expect(XML.parse_html(response.body).xpath_nodes("/html//title").first).to match(/Payload Too Large/)
      end
    end

    context "given a path that is not an actor's inbox" do
      let(path) { "/actors/foo_bar/inbox/more" }

      it "does not apply the inbox limit" do
        expect(response.status_code).to eq(413)
      end
    end

    context "given a path that is not an actor's inbox" do
      let(path) { "/foo/bar/inbox" }

      it "does not apply the inbox limit" do
        expect(response.status_code).to eq(413)
      end
    end
  end

  context "with a content length at the anonymous limit" do
    let(content_length) { ANONYMOUS_LIMIT }

    it "passes the request on to the next handler" do
      response
      expect(next_handler.called?).to be_true
    end
  end

  context "with a content length over the anonymous limit" do
    let(content_length) { ANONYMOUS_LIMIT + 1 }

    it "refuses the request" do
      expect(response.status_code).to eq(413)
    end
  end

  context "given a delivery to an actor's inbox" do
    let(path) { "/actors/foo_bar/inbox" }
    let(body_size) { INBOX_LIMIT }

    it "allows a body up to the inbox limit" do
      response
      expect(next_handler.received_bytes).to eq(INBOX_LIMIT)
    end

    context "with a body over the inbox limit" do
      let(body_size) { INBOX_LIMIT + 1 }

      it "refuses the request" do
        expect(response.status_code).to eq(413)
      end
    end
  end

  context "given a delivery to the shared inbox" do
    let(path) { "/inbox" }
    let(body_size) { INBOX_LIMIT }

    it "allows a body up to the inbox limit" do
      response
      expect(next_handler.received_bytes).to eq(INBOX_LIMIT)
    end

    context "with a body over the inbox limit" do
      let(body_size) { INBOX_LIMIT + 1 }

      it "refuses the request" do
        expect(response.status_code).to eq(413)
      end
    end
  end

  context "given an authenticated request" do
    sign_in

    let(body_size) { AUTHENTICATED_LIMIT }

    it "allows a body up to the authenticated limit" do
      response
      expect(next_handler.received_bytes).to eq(AUTHENTICATED_LIMIT)
    end

    context "with a body over the authenticated limit" do
      let(body_size) { AUTHENTICATED_LIMIT + 1 }

      it "refuses the request" do
        expect(response.status_code).to eq(413)
      end
    end
  end
end
