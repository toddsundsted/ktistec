require "../../src/models/relationship/content/follow/hashtag"
require "../../src/models/relationship/content/follow/mention"
require "../../src/models/relationship/content/notification/follow/hashtag"
require "../../src/models/relationship/content/notification/follow/mention"
require "../../src/models/relationship/content/notification/follow/thread"
require "../../src/models/relationship/content/notification/poll/expiry"

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

    context "given a dislike notification" do
      let_build(:dislike)
      let_create!(:notification_dislike, owner: actor, activity: dislike)

      it "renders a disliking message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("#{dislike.actor.display_name} disliked your post.")
      end

      context "given another dislike notification" do
        let_create!(:dislike, named: another, object: dislike.object)

        it "renders a disliking message" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
            to eq("#{dislike.actor.display_name} and 1 other disliked your post.")
        end
      end
    end

    context "given a mention notification" do
      let_build(:object)
      let_create!(:notification_mention, owner: actor, object: object)

      it "renders a message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to have("#{object.attributed_to.display_name} mentioned you.")
      end
    end

    context "given a follow hashtag notification" do
      let_build(:object, content: "This is the content.", published: Time.utc)
      let_create!(:notification_follow_hashtag, owner: actor, name: "foo")

      before_each do
        Factory.create(:hashtag, name: "foo", subject: object)
        Factory.create(:hashtag, name: "bar", subject: object)
      end

      it "renders a message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
          to have("There are new posts tagged with ", "#foo", ".")
      end

      it "renders the content" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
          to have("This is the content.")
      end

      context "given a deleted object" do
        before_each { object.delete! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
            not_to have("This is the content.")
        end
      end

      context "given a blocked object" do
        before_each { object.block! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
            not_to have("This is the content.")
        end
      end
    end

    context "given a follow mention notification" do
      let_build(:object, content: "This is the content.", published: Time.utc)
      let_create!(:notification_follow_mention, owner: actor, name: "foo@bar")

      let_create!(:follow_mention_relationship, named: nil, actor: actor, name: "foo@bar")

      before_each do
        Factory.create(:mention, name: "foo@bar", subject: object)
        Factory.create(:mention, name: "bar@foo", subject: object)
      end

      it "renders a message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
          to have("There are new posts that mention ", "@foo@bar", ".")
      end

      it "renders the content" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
          to have("This is the content.")
      end

      context "given a deleted object" do
        before_each { object.delete! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
            not_to have("This is the content.")
        end
      end

      context "given a blocked object" do
        before_each { object.block! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()")).
            not_to have("This is the content.")
        end
      end
    end

    context "given a thread follow notification for a reply" do
      let_build(:object)
      let_build(:object, named: reply, in_reply_to: object)
      let_create!(:notification_follow_thread, owner: actor, object: reply)

      pre_condition { expect(reply.root?).to be_false }

      it "renders a replied to message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("#{reply.attributed_to.display_name} replied to a thread you follow.")
      end
    end

    context "given a thread thread notification for the root" do
      let_build(:object)
      let_create!(:notification_follow_thread, owner: actor, object: object)

      pre_condition { expect(object.root?).to be_true }

      it "renders a fetch the root of the thread message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to eq("There are replies to a thread you follow.")
      end
    end

    context "given a poll expiry notification" do
      let_create!(:question, name: "What is your favorite color?")
      let_create!(:notification_poll_expiry, owner: actor, question: question)

      it "renders poll expiry message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join).
          to match(/A poll you voted in has ended/)
      end

      it "includes link to poll results" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//a/@href").first.text).
          to eq("/remote/objects/#{question.id}")
      end
    end
  end

  describe "notifications.json.ecr" do
    let(env) { env_factory("GET", "/notifications") }

    subject do
      begin
        JSON.parse(render "./src/views/actors/notifications.json.ecr")
      rescue JSON::ParseException
        JSON.parse("{}")
      end
    end

    let(account) { register }
    let(actor) { account.actor }

    let(notifications) { actor.notifications }

    it "renders an empty collection" do
      expect(subject["first"]["orderedItems"].as_a).to be_empty
    end
  end
end
