require "../../src/controllers/streams"

require "../spec_helper/controller"

Spectator.describe StreamsController do
  setup_spec

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
