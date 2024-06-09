require "../../src/controllers/streams"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe StreamsController do
  setup_spec

  describe "GET /stream/tags/:hashtag" do
    it "returns 401 if not authorized" do
      get "/stream/tags/hashtag"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the hashtag does not exist" do
        get "/stream/tags/hashtag"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "/stream/objects/:id/thread" do
    it "returns 401 if not authorized" do
      get "/stream/objects/1/thread"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if the object does not exist" do
        get "/stream/objects/1/thread"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe ".stream_action" do
    it "sends the body in a Turbo Stream / Server-Sent Events wrapper" do
      str = String.build do |io|
        described_class.stream_action(io, body: "<br>\n<br>\n<br>", action: "foobar", id: "target", selector: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar" target="target">
      data: <template>
      data: <br>
      data: <br>
      data: <br>
      data: </template>
      data: </turbo-stream>
      \n
      HTML
    end

    it "sends the body in a Turbo Stream / Server-Sent Events wrapper" do
      str = String.build do |io|
        described_class.stream_action(io, body: "<br>\n<br>\n<br>", action: "foobar", selector: "target", id: nil)
      end
      expect(str).to eq <<-HTML
      data: <turbo-stream action="foobar" targets="target">
      data: <template>
      data: <br>
      data: <br>
      data: <br>
      data: </template>
      data: </turbo-stream>
      \n
      HTML
    end
  end
end
