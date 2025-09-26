require "../../src/models/activity_pub/activity/follow"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "actor" do
  setup_spec

  describe "actor.html.slang" do
    let_create(:actor)

    let(env) { env_factory("GET", "/actor/username") }

    module ::Ktistec::ViewHelper
      def self.render_actor_html_slang(env, actor)
        render "./src/views/actors/actor.html.slang"
      end
    end

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper.render_actor_html_slang(env, actor))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    it "does not render an editor" do
      expect(subject.xpath_nodes("//trix-editor")).to be_empty
    end

    context "if authenticated" do
      sign_in

      it "does not render an editor" do
        expect(subject.xpath_nodes("//trix-editor")).to be_empty
      end

      context "if account actor is actor" do
        let(actor) { env.account.actor }

        it "renders an editor" do
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end
      end
    end
  end
end
