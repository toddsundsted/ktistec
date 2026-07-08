require "../../src/framework/exceptions"
require "../../src/framework/controller"

require "../spec_helper/controller"

class ExceptionsController
  include Ktistec::Controller

  skip_auth ["/exceptions/test"], POST

  post "/exceptions/test" do |env|
    env.response.status_code = 200
    "ok"
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
