require "../../src/models/activity_pub/activity/follow"
require "../../src/models/relationship/content/notification/**" # ameba:disable Ktistec/NoRequireGlob
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "actor" do
  setup_spec

  describe "actor.html.slang" do
    let_create(:actor)

    let(env) { make_env("GET", "/actor/username") }

    let(pinned) { [] of ActivityPub::Object }
    let(objects) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

    module ::Ktistec::ViewHelper
      def self.render_actor_html_slang(env, actor, pinned, objects)
        render "./src/views/actors/actor.html.slang"
      end
    end

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper.render_actor_html_slang(env, actor, pinned, objects))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    it "does not render an editor" do
      expect(subject.xpath_nodes("//trix-editor")).to be_empty
    end
  end

  describe "self.html.slang" do
    let(env) { make_env("GET", "/actor/username") }

    let(feed) { nil.as(Feed?) }

    let(objects) { Ktistec::Util::PaginatedArray(ActivityPub::Object).new }

    module ::Ktistec::ViewHelper
      def self.render_self_html_slang(env, actor, feed, objects)
        render "./src/views/actors/self.html.slang"
      end
    end

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper.render_self_html_slang(env, actor, feed, objects))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    sign_in

    let(actor) { env.account.actor }

    it "renders an editor" do
      expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
    end

    it "renders a stream source" do
      expect(subject.xpath_nodes("//turbo-stream-source")).not_to be_empty
    end

    context "given a query string" do
      let(env) { make_env("GET", "/actor/username?foo=bar") }

      it "renders a stream source with the query string" do
        expect(subject.xpath_nodes("//turbo-stream-source/@src").first).to eq("/stream/actor/homepage?foo=bar")
      end
    end

    describe "timeline controls" do
      it "targets the main timeline" do
        expect(subject.xpath_nodes("//form[@id='timeline-controls']/@data-turbo-frame").map(&.text)).to eq(["main-timeline"])
      end

      it "renders the controls outside the main timeline" do
        expect(subject.xpath_nodes("//form[@id='timeline-controls'][following-sibling::turbo-frame[@id='main-timeline']]")).not_to be_empty
      end

      it "renders an empty filter" do
        expect(subject.xpath_nodes("//form[@id='timeline-controls']//input[@type='hidden'][@name='filters'][@value='']")).not_to be_empty
      end

      context "given a query parameter" do
        let(env) { make_env("GET", "/actor/username?foo=bar") }

        it "renders the parameter as a hidden field" do
          expect(subject.xpath_nodes("//form[@id='timeline-controls']//input[@type='hidden'][@name='foo']/@value").map(&.text)).to eq(["bar"])
        end
      end

      context "given a filter" do
        let(env) { make_env("GET", "/actor/username?filters=no-shares") }

        pre_condition { expect(subject.xpath_nodes("//form[@id='timeline-controls']")).not_to be_empty }

        it "does not render the filter as a hidden field" do
          expect(subject.xpath_nodes("//form[@id='timeline-controls']//input[@type='hidden'][@name='filters'][@value='no-shares']")).to be_empty
        end
      end

      {% for filter in ["no-shares", "no-replies"] %}
        describe "the {{filter.id}} toggle" do
          it "renders unchecked" do
            expect(subject.xpath_nodes("//form[@id='timeline-controls']//input[@type='checkbox'][@value='{{filter.id}}'][not(@checked)]")).not_to be_empty
          end

          context "given the {{filter.id}} filter" do
            let(env) { make_env("GET", "/actor/username?filters={{filter.id}}") }

            it "renders checked" do
              expect(subject.xpath_nodes("//form[@id='timeline-controls']//input[@type='checkbox'][@value='{{filter.id}}'][@checked]")).not_to be_empty
            end
          end
        end
      {% end %}
    end

    before_each do
      env.account.assign(last_notifications_checked_at: 1.hour.ago).save
    end

    let(tooltip) { subject.xpath_nodes("//a[contains(@href,'notifications')]//span[contains(@class,'label')]/@title").first?.try(&.text) }
    let(color) do
      subject.xpath_nodes("//a[contains(@href,'notifications')]//span[contains(@class,'label')]").first?.try do |elem|
        elem["class"].split.find(&.in? ["red", "orange", "yellow"])
      end
    end

    it "does not render tooltip" do
      expect(tooltip).to be_nil
    end

    it "does not render visible label" do
      expect(color).to be_nil
    end

    context "given a follow notification" do
      let_create!(:notification_follow, owner: actor)

      it "renders follow tooltip" do
        expect(tooltip).to eq("follow 1")
      end

      it "renders red label" do
        expect(color).to eq("red")
      end
    end

    context "given a reply notification" do
      let_create!(:notification_reply, owner: actor)

      it "renders reply tooltip" do
        expect(tooltip).to eq("reply 1")
      end

      it "renders red label" do
        expect(color).to eq("red")
      end
    end

    context "given a mention notification" do
      let_create!(:notification_mention, owner: actor)

      it "renders mention tooltip" do
        expect(tooltip).to eq("mention 1")
      end

      it "renders red label" do
        expect(color).to eq("red")
      end
    end

    context "given an announce notification" do
      let_create!(:notification_announce, owner: actor)

      it "renders social tooltip" do
        expect(tooltip).to eq("social 1")
      end

      it "renders orange label" do
        expect(color).to eq("orange")
      end
    end

    context "given a like notification" do
      let_create!(:notification_like, owner: actor)

      it "renders social tooltip" do
        expect(tooltip).to eq("social 1")
      end

      it "renders orange label" do
        expect(color).to eq("orange")
      end
    end

    context "given a dislike notification" do
      let_create!(:notification_dislike, owner: actor)

      it "renders social tooltip" do
        expect(tooltip).to eq("social 1")
      end

      it "renders orange label" do
        expect(color).to eq("orange")
      end
    end

    context "given a follow hashtag notification" do
      let_create!(:notification_follow_hashtag, owner: actor, name: "foo")

      it "renders content tooltip" do
        expect(tooltip).to eq("content 1")
      end

      it "renders yellow label" do
        expect(color).to eq("yellow")
      end
    end

    context "given a follow mention notification" do
      let_create!(:notification_follow_mention, owner: actor, href: "https://bar/users/foo")

      it "renders content tooltip" do
        expect(tooltip).to eq("content 1")
      end

      it "renders yellow label" do
        expect(color).to eq("yellow")
      end
    end

    context "given a follow thread notification" do
      let_create!(:notification_follow_thread, owner: actor)

      it "renders content tooltip" do
        expect(tooltip).to eq("content 1")
      end

      it "renders yellow label" do
        expect(color).to eq("yellow")
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

      it "renders red label" do
        expect(color).to eq("red")
      end
    end
  end

  describe "actor.json.ecr" do
    let_create(:actor)

    let(env) { make_env("GET", "/actor/username") }

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

      it "renders the server's shared inbox endpoint" do
        expect(subject.dig?("endpoints", "sharedInbox")).to eq("https://test.test/inbox")
      end
    end
  end
end
