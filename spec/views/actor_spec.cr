require "../../src/models/activity_pub/activity/follow"
require "../../src/models/relationship/content/notification/**"
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

        before_each do
          env.account.assign(last_notifications_checked_at: 1.hour.ago).save
        end

        let(tooltip) { subject.xpath_nodes("//a[contains(@href,'notifications')]/@title").first?.try(&.text) }

        it "does not render tooltip" do
          expect(tooltip).to be_nil
        end

        context "given a follow notification" do
          let_create!(:notification_follow, owner: actor)

          it "renders follow tooltip" do
            expect(tooltip).to eq("follow 1")
          end
        end

        context "given a reply notification" do
          let_create!(:notification_reply, owner: actor)

          it "renders reply tooltip" do
            expect(tooltip).to eq("reply 1")
          end
        end

        context "given a mention notification" do
          let_create!(:notification_mention, owner: actor)

          it "renders mention tooltip" do
            expect(tooltip).to eq("mention 1")
          end
        end

        context "given an announce notification" do
          let_create!(:notification_announce, owner: actor)

          it "renders social tooltip" do
            expect(tooltip).to eq("social 1")
          end
        end

        context "given a like notification" do
          let_create!(:notification_like, owner: actor)

          it "renders social tooltip" do
            expect(tooltip).to eq("social 1")
          end
        end

        context "given a dislike notification" do
          let_create!(:notification_dislike, owner: actor)

          it "renders social tooltip" do
            expect(tooltip).to eq("social 1")
          end
        end

        context "given a follow hashtag notification" do
          let_create!(:notification_follow_hashtag, owner: actor, name: "foo")

          it "renders content tooltip" do
            expect(tooltip).to eq("content 1")
          end
        end

        context "given a follow mention notification" do
          let_create!(:notification_follow_mention, owner: actor, name: "foo@bar")

          it "renders content tooltip" do
            expect(tooltip).to eq("content 1")
          end
        end

        context "given a follow thread notification" do
          let_create!(:notification_follow_thread, owner: actor)

          it "renders content tooltip" do
            expect(tooltip).to eq("content 1")
          end
        end

        context "given multiple notifications" do
          let_create!(:notification_like, owner: actor)
          let_create!(:notification_dislike, owner: actor)
          let_create!(:notification_follow_thread, owner: actor)
          let_create!(:notification_follow, named: :notif_follow1, owner: actor)
          let_create!(:notification_follow, named: :notif_follow2, owner: actor)

          it "renders combined tooltip" do
            expect(tooltip).to eq("follow 2 | social 2 | content 1")
          end
        end
      end
    end
  end

  describe "actor.json.ecr" do
    let_create(:actor)

    let(env) { env_factory("GET", "/actor/username") }

    module ::Ktistec::ViewHelper
      def self.render_actor_json_ecr(env, actor)
        render "./src/views/actors/actor.json.ecr"
      end
    end

    subject do
      begin
        JSON.parse(Ktistec::ViewHelper.render_actor_json_ecr(env, actor))
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
