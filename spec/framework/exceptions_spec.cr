require "../../src/framework/exceptions"
require "../../src/framework/controller"

require "../spec_helper/controller"

class ExceptionsController
  include Ktistec::Controller

  skip_auth ["/exceptions/test"], POST
  skip_auth ["/exceptions/large"], GET

  post "/exceptions/test" do |env|
    env.response.status_code = 200
    "ok"
  end

  get "/exceptions/large" do |env|
    # larger than the response buffer, so the write reaches the socket
    env.response.print "x" * (IO::DEFAULT_BUFFER_SIZE * 2)
    ""
  end
end

class BrokenPipeIO < IO
  def read(slice : Bytes) : Int32
    raise NotImplementedError.new("read")
  end

  def write(slice : Bytes) : Nil
    raise IO::Error.from_os_error("write", Errno::EPIPE, target: self)
  end
end

Spectator.describe "malformed request body handling" do
  it "returns 400 when the body is truncated" do
    headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=1Aa"}
    body = %Q|--1Aa\r\nContent-Disposition: form-data; name="foo"\r\n\r\nbar|
    post "/exceptions/test", headers, body
    expect(response.status_code).to eq(400)
  end

  it "returns 400 when the content type has no boundary" do
    headers = HTTP::Headers{"Content-Type" => "multipart/form-data"}
    post "/exceptions/test", headers, "whatever"
    expect(response.status_code).to eq(400)
  end
end

Spectator.describe "client disconnect handling" do
  let(request) { HTTP::Request.new("GET", "/exceptions/large") }
  let(context) { HTTP::Server::Context.new(request, HTTP::Server::Response.new(BrokenPipeIO.new)) }

  it "writes to the disconnected client" do
    build_main_handler.call(context) rescue nil
    expect(context.response.closed?).to be_true
  end

  it "does not log errors" do
    entries = capture_log("kemal") { build_main_handler.call(context) rescue nil }
    expect(entries.map(&.message)).to be_empty
  end

  it "does not raise" do
    expect { build_main_handler.call(context) }.not_to raise_error
  end
end
