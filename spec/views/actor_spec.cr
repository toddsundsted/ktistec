require "../../src/models/activity_pub/activity/follow"
require "../../src/views/view_helper"

require "../spec_helper/controller"

Spectator.describe "actor" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "actor.html.slang" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/actor/username"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

    let(actor) do
      ActivityPub::Actor.new(
        iri: "https://remote.test/actors/foo_bar"
      ).save
    end

    subject do
      begin
        XML.parse_html(render "./src/views/actors/actor.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    it "does not render an editor" do
      expect(subject.xpath_nodes("//trix-editor")).to be_empty
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      it "does not render an editor" do
        expect(subject.xpath_nodes("//trix-editor")).to be_empty
      end

      context "if account actor is actor" do
        let(actor) { account.actor }

        it "renders an editor" do
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end
      end
    end
  end
end
