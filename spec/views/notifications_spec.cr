require "../../src/models/relationship/content/follow/hashtag"
require "../../src/models/relationship/content/follow/mention"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "notifications partial" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "notifications.html.slang" do
    let(env) { env_factory("GET", "/notifications") }

    subject do
      begin
        XML.parse_html(render "./src/views/actors/notifications.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let(account) { register }
    let(actor) { account.actor }

    let(notifications) { actor.notifications }

    it "renders an empty page" do
      expect(subject.xpath_nodes("//text()")).to have(/There is nothing here/)
    end

    context "given an announce notification" do
      let_build(:announce)
      let_create!(:notification_announce, owner: actor, activity: announce)

      it "renders a sharing message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("#{announce.actor.display_name} shared your post.")
      end

      context "given another announce notification" do
        let_create!(:announce, named: another, object: announce.object)

        it "renders a sharing message" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
            to eq("#{announce.actor.display_name} and 1 other shared your post.")
        end
      end
    end

    context "given a like notification" do
      let_build(:like)
      let_create!(:notification_like, owner: actor, activity: like)

      it "renders a liking message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("#{like.actor.display_name} liked your post.")
      end

      context "given another like notification" do
        let_create!(:like, named: another, object: like.object)

        it "renders a liking message" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
            to eq("#{like.actor.display_name} and 1 other liked your post.")
        end
      end
    end

    context "given a hashtag notification" do
      let_build(:object)
      let_build(:announce, object: object)
      let_create!(:notification_hashtag, owner: actor, activity: announce)

      let_create!(:follow_hashtag_relationship, named: nil, actor: actor, name: "foo")

      before_each do
        Factory.create(:hashtag, name: "foo", subject: object)
        Factory.create(:hashtag, name: "bar", subject: object)
      end

      it "renders a tagged message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("#{object.attributed_to.display_name} tagged a post with #foo.")
      end
    end

    context "given a mention notification" do
      let_build(:object)
      let_build(:like, object: object)
      let_create!(:notification_mention, owner: actor, activity: like)

      let_create!(:follow_mention_relationship, named: nil, actor: actor, name: "foo")

      before_each do
        Factory.create(:mention, name: "foo", subject: object)
        Factory.create(:mention, name: "bar", subject: object)
      end

      it "renders a tagged message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("#{object.attributed_to.display_name} tagged a post with @foo.")
      end
    end
  end
end
