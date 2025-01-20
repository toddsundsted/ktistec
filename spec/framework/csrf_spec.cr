# The MIT License (MIT)

# Copyright (c) 2016 Serdar Dogruyol

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require "../../src/framework/csrf"

private def process_request_and_return_response(handler, request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  {context, HTTP::Client::Response.from_io(io.rewind, decompress: false)}
end

Spectator.describe Ktistec::CSRF do
  it "sends GETs to next handler" do
    handler = described_class.new
    request = HTTP::Request.new("GET", "/")
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)
  end

  it "generates an authenticity token on HTML requests" do
    handler = described_class.new
    handler.next = ->(context : HTTP::Server::Context) { }
    request = HTTP::Request.new("GET", "/",
      headers: HTTP::Headers{"Accept" => %q|text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8|})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.cookies["authenticity_token"]?.try(&.value)).not_to be_nil
  end

  it "does not generate an authenticity token on non-HTML requests" do
    handler = described_class.new
    handler.next = ->(context : HTTP::Server::Context) { }
    request = HTTP::Request.new("GET", "/",
      headers: HTTP::Headers{"Accept" => %q|application/json|})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.cookies["authenticity_token"]?.try(&.value)).to be_nil
  end

  it "allows POSTs with safe content types" do
    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      headers: HTTP::Headers{"Content-Type" => %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      headers: HTTP::Headers{"Content-Type" => "application/activity+json"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      headers: HTTP::Headers{"Content-Type" => "application/json"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)
  end

  it "blocks POSTs without the token" do
    handler = described_class.new
    request = HTTP::Request.new("POST", "/")
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      body: "foo=bar",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      body: %Q|--1Aa\r\nContent-Disposition: form-data; name="foo"\r\n\r\nbar\r\n--1Aa--"|,
      headers: HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=1Aa"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      headers: HTTP::Headers{"Content-Type" => "text/plain"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)
  end

  it "allows POSTs with the correct token in FORM submit" do
    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      body: "authenticity_token=cemal&hasan=lamec",
      headers: HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"})
    context, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)

    csrf = context.session.string("csrf")

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      body: "authenticity_token=#{csrf}&hasan=lamec",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded",
                             "Cookie" => client_response.headers["Set-Cookie"]})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)
  end

  it "allows POSTs with the correct token in HTTP header" do
    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      body: "hasan=lamec",
      headers: HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"})
    context, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)

    csrf = context.session.string("csrf")

    handler = described_class.new
    request = HTTP::Request.new("POST", "/",
      body: "hasan=lamec",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded",
                             "Cookie" => client_response.headers["Set-Cookie"],
                             "X-CSRF-Token" => csrf})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)
  end

  it "allows POSTs to allowed route" do
    handler = described_class.new(allowed_routes: ["/allowed"])
    request = HTTP::Request.new("POST", "/allowed/",
      body: "authenticity_token=cemal&hasan=lamec",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)
  end

  it "allows POSTs to allowed route using wildcards" do
    handler = described_class.new(allowed_routes: ["/everything/*"])
    request = HTTP::Request.new("POST", "/everything/here/and",
      body: "authenticity_token=cemal&hasan=lamec",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(404)
  end

  it "does not allow POSTs to mismatched route using wildcards" do
    handler = described_class.new(allowed_routes: ["/nothing/*"])
    request = HTTP::Request.new("POST", "/something/",
      body: "authenticity_token=cemal&hasan=lamec",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"})
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)
  end

  it "outputs error string" do
    handler = described_class.new(error: "Oh no you have an error")
    request = HTTP::Request.new("POST", "/")
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)
    expect(client_response.body).to eq("Oh no you have an error")
  end

  it "calls an error proc with context" do
    handler = described_class.new(error: ->myerrorhandler(HTTP::Server::Context))
    request = HTTP::Request.new("POST", "/")
    _, client_response = process_request_and_return_response(handler, request)
    expect(client_response.status_code).to eq(403)
    expect(client_response.body).to eq("Error from handler")
  end
end

def myerrorhandler(context : HTTP::Server::Context)
  "Error from handler"
end
