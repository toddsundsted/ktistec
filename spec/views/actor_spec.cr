require "../../src/models/activity_pub/activity/follow"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "actor" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "actor.html.slang" do
    let_create(:actor)

    let(env) { env_factory("GET", "/actor/username") }

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

  describe "actor.json.ecr" do
    let_create(:actor)

    let(env) { env_factory("GET", "/actor/username") }

    subject do
      begin
        JSON.parse(render "./src/views/actors/actor.json.ecr")
      rescue JSON::ParseException
        JSON.parse("{}")
      end
    end

    it "does not render a shared inbox endpoint" do
      expect(subject.dig?("endpoints", "sharedInbox")).to be_nil
    end

    context "if local" do
      before_each { actor.assign(iri: "https://test.test/actor") }

      it "renders a shared inbox endpoint" do
        expect(subject.dig?("endpoints", "sharedInbox")).not_to be_nil
      end
    end
  end
end
