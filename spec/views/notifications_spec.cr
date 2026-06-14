require "../../src/models/relationship/content/follow/hashtag"
require "../../src/models/relationship/content/follow/mention"
require "../../src/models/relationship/content/notification/follow/hashtag"
require "../../src/models/relationship/content/notification/follow/mention"
require "../../src/models/relationship/content/notification/follow/thread"
require "../../src/models/relationship/content/notification/mention"
require "../../src/models/relationship/content/notification/poll/expiry"
require "../../src/models/relationship/content/notification/reply"
require "../../src/models/relationship/content/notification/quote"
require "../../src/models/activity_pub/activity/quote_request"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "notifications partial" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "notifications.html.slang" do
    let(env) { make_env("GET", "/notifications") }

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
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to eq("#{announce.actor.display_name} shared your post.")
      end

      context "given another announce notification" do
        let_create!(:announce, named: another, object: announce.object)

        it "renders a sharing message" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
            .to eq("#{announce.actor.display_name} and 1 other shared your post.")
        end
      end
    end

    context "given a like notification" do
      let_build(:like)
      let_create!(:notification_like, owner: actor, activity: like)

      it "renders a liking message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to eq("#{like.actor.display_name} liked your post.")
      end

      context "given another like notification" do
        let_create!(:like, named: another, object: like.object)

        it "renders a liking message" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
            .to eq("#{like.actor.display_name} and 1 other liked your post.")
        end
      end
    end

    context "given a dislike notification" do
      let_build(:dislike)
      let_create!(:notification_dislike, owner: actor, activity: dislike)

      it "renders a disliking message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to eq("#{dislike.actor.display_name} disliked your post.")
      end

      context "given another dislike notification" do
        let_create!(:dislike, named: another, object: dislike.object)

        it "renders a disliking message" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
            .to eq("#{dislike.actor.display_name} and 1 other disliked your post.")
        end
      end
    end

    context "given a mention notification" do
      let_build(:object)
      let_create!(:notification_mention, owner: actor, object: object)

      it "renders a message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to have("#{object.attributed_to.display_name} mentioned you.")
      end
    end

    context "given a follow hashtag notification" do
      let_build(:object, content: "This is the content.", published: Time.utc)
      let_create!(:notification_follow_hashtag, owner: actor, name: "foo")
      let_create!(:hashtag, named: nil, name: "foo", subject: object)
      let_create!(:hashtag, named: nil, name: "bar", subject: object)

      it "renders a message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
          .to have("There are new posts tagged with ", "#foo", ".")
      end

      it "renders the content" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
          .to have("This is the content.")
      end

      context "given a deleted object" do
        before_each { object.delete! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
            .not_to have("This is the content.")
        end
      end

      context "given a blocked object" do
        before_each { object.block! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
            .not_to have("This is the content.")
        end
      end
    end

    context "given a follow mention notification" do
      let_build(:object, content: "This is the content.", published: Time.utc)
      let_create!(:notification_follow_mention, owner: actor, href: "https://bar/users/foo")
      let_create!(:follow_mention_relationship, named: nil, actor: actor, href: "https://bar/users/foo")
      let_create!(:mention, named: nil, name: "foo@bar", href: "https://bar/users/foo", subject: object)
      let_create!(:mention, named: nil, name: "bar@foo", href: "https://foo/users/bar", subject: object)

      it "renders a message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
          .to have("There are new posts that mention ", "@foo@bar", ".")
      end

      it "renders the content" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
          .to have("This is the content.")
      end

      context "given a deleted object" do
        before_each { object.delete! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
            .not_to have("This is the content.")
        end
      end

      context "given a blocked object" do
        before_each { object.block! }

        it "does not render the content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
            .not_to have("This is the content.")
        end
      end
    end

    context "given a thread follow notification for a reply" do
      let_build(:object)
      let_build(:object, named: reply, in_reply_to: object)
      let_create!(:notification_follow_thread, owner: actor, object: reply)

      pre_condition { expect(reply.root?).to be_false }

      it "renders a replied to message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to eq("#{reply.attributed_to.display_name} replied to a thread you follow.")
      end
    end

    context "given a thread notification for the root" do
      let_build(:object)
      let_create!(:notification_follow_thread, owner: actor, object: object)

      pre_condition { expect(object.root?).to be_true }

      it "renders a fetch the root of the thread message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to eq("There are replies to a thread you follow.")
      end
    end

    context "given a poll expiry notification" do
      let_create!(:question, name: "What is your favorite color?", attributed_to: actor)
      let_create!(:notification_poll_expiry, owner: actor, question: question)

      it "renders poll expiry message for author" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to match(/A poll you created has ended/)
      end

      it "includes link to poll results" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//a/@href").first.text)
          .to eq("/remote/objects/#{question.id}")
      end
    end

    context "given a poll expiry notification" do
      let_create!(:question, name: "What is your favorite color?")
      let_create!(:notification_poll_expiry, owner: actor, question: question)

      it "renders poll expiry message for voter" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to match(/A poll you voted in has ended/)
      end

      it "includes link to poll results" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//a/@href").first.text)
          .to eq("/remote/objects/#{question.id}")
      end
    end

    context "given a quote notification" do
      let_build(:object, named: quoted_post, attributed_to: actor)
      let_build(:actor, named: quoting_actor)
      let_build(:quote_request, actor: quoting_actor, object: quoted_post)
      let_create!(:notification_quote, owner: actor, activity: quote_request)

      it "renders a quoting message" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()").join)
          .to eq("#{quoting_actor.display_name} quoted your post.")
      end

      it "displays the actor who quoted" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//a/@href").first.text)
          .to eq("/remote/actors/#{quoting_actor.id}")
      end

      it "links to the quoted post" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//a[contains(text(),'your post')]/@href").map(&.text))
          .to have("/remote/objects/#{quoted_post.id}")
      end

      it "does not link to the quoting post" do
        expect(subject.xpath_nodes("//article[contains(@class,'event')]//a[contains(text(),'quoted')]/@href").map(&.text))
          .to be_empty
      end

      context "when the quoting post is cached" do
        let_build(:object, named: quoting_post, attributed_to: quoting_actor)
        before_each { quote_request.assign(instrument: quoting_post).save }

        it "links to the quoting post" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//a[contains(text(),'quoted')]/@href").map(&.text))
            .to have("/remote/objects/#{quoting_post.id}")
        end
      end

      context "with content preview" do
        before_each { quoted_post.assign(content: "This is the quoted content.").save }

        it "shows a preview of the quoted content" do
          expect(subject.xpath_nodes("//article[contains(@class,'event')]//text()"))
            .to have("This is the quoted content.")
        end
      end
    end
  end

  describe "notifications.json.ecr" do
    let(env) { make_env("GET", "/notifications") }

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

    let(items) { subject["first"]["orderedItems"].as_a.map(&.as_s) }

    it "renders an empty collection" do
      expect(items).to be_empty
    end

    context "given an announce notification" do
      let_build(:announce)
      let_create!(:notification_announce, owner: actor, activity: announce)

      it "emits the activity iri" do
        expect(items).to eq([announce.iri])
      end
    end

    context "given a reply notification" do
      let_build(:object)
      let_create!(:notification_reply, owner: actor, object: object)

      it "emits the object iri" do
        expect(items).to eq([object.iri])
      end
    end

    context "given a mention notification" do
      let_build(:object)
      let_create!(:notification_mention, owner: actor, object: object)

      it "emits the object iri" do
        expect(items).to eq([object.iri])
      end
    end

    context "given a poll expiry notification" do
      let_create!(:question)
      let_create!(:notification_poll_expiry, owner: actor, question: question)

      it "emits the question iri" do
        expect(items).to eq([question.iri])
      end
    end

    context "given a thread follow notification" do
      let_build(:object)
      let_create!(:notification_follow_thread, owner: actor, object: object)

      it "emits the object iri" do
        expect(items).to eq([object.iri])
      end
    end

    context "given a hashtag follow notification" do
      let_create!(:notification_follow_hashtag, owner: actor, name: "foo")

      it "falls back to the hashtag page iri" do
        expect(items).to eq(["#{Ktistec.host}#{Utils::Paths.hashtag_path("foo")}"])
      end

      context "with a tagged object" do
        let_build(:object, published: Time.utc)
        let_create!(:hashtag, named: nil, name: "foo", subject: object)

        it "emits the iri of the most recent tagged object" do
          expect(items).to eq([object.iri])
        end
      end
    end

    context "given a mention follow notification" do
      let_create!(:notification_follow_mention, owner: actor, href: "https://bar/users/foo")

      it "falls back to the followed actor iri" do
        expect(items).to eq(["https://bar/users/foo"])
      end

      context "with a mentioning object" do
        let_build(:object, published: Time.utc)
        let_create!(:mention, named: nil, name: "foo@bar", href: "https://bar/users/foo", subject: object)

        it "emits the iri of the most recent mentioning object" do
          expect(items).to eq([object.iri])
        end
      end
    end

    context "given an emitted iri with json-significant characters" do
      let_create!(:notification_follow_mention, owner: actor, href: %q{https://bar/users/a"b\c})

      it "emits a properly escaped json string" do
        expect(items).to eq([%q{https://bar/users/a"b\c}])
      end
    end
  end
end
