require "../../src/models/activity_pub/object/note"
require "../../src/models/activity_pub/object/question"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/like"
require "../../src/models/translation"
require "../../src/framework/controller"
require "../../src/utils/translator"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "object partials" do
  setup_spec

  include Ktistec::Controller

  describe "label.html.slang" do
    let(env) { env_factory("GET", "/object") }

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper._view_src_views_partials_object_label_html_slang(env, author, actor))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let_build(:actor, icon: random_string)

    context "the actor is the author" do
      let(author) { actor }

      it "renders one profile icon" do
        expect(subject.xpath_nodes("//img/@src")).to contain_exactly(author.icon)
      end

      context "and the author is deleted" do
        before_each { author.delete! }

        it "renders the deleted icon" do
          expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain("/images/avatars/deleted.png")
        end
      end

      context "and the author is blocked" do
        before_each { author.block! }

        it "renders the blocked icon" do
          expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain("/images/avatars/blocked.png")
        end
      end
    end

    context "the actor is not the author" do
      let_build(:actor, named: author, icon: random_string)

      it "renders two profile icons" do
        expect(subject.xpath_nodes("//img/@src")).to contain_exactly(actor.icon, author.icon)
      end

      context "and the actor is deleted" do
        before_each { actor.delete! }

        it "renders the deleted icon" do
          expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain("/images/avatars/deleted.png")
        end
      end

      context "and the actor is blocked" do
        before_each { actor.block! }

        it "renders the blocked icon" do
          expect(subject.xpath_nodes("//img/@src").map(&.text)).to contain("/images/avatars/blocked.png")
        end
      end
    end
  end

  describe "content.html.slang" do
    let(env) { env_factory("GET", "/object") }

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper._view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, for_thread, for_actor))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let(account) { register }
    let(actor) { account.actor }
    let(author) { actor }

    let_create!(:object, attributed_to: actor, published: Time.utc)
    let_build(:object, named: :original)

    let(with_detail) { false }
    let(for_thread) { nil }
    let(for_actor) { nil }

    context "given HTML content" do
      before_each { object.assign(content: "<ul><li>One</li><li>Two</li></ul>", media_type: "text/html") }

      it "renders the content as is" do
        expect(subject.xpath_nodes("//ul/li/text()")).to contain_exactly("One", "Two")
      end

      context "and a translation" do
        let_create!(:translation, origin: object, content: "<ul><li>Un</li><li>Du</li></ul>")

        it "renders the translation of the content" do
          expect(subject.xpath_nodes("//ul/li/text()")).to contain_exactly("Un", "Du")
        end
      end
    end

    context "given Markdown content" do
      before_each { object.assign(content: "* One\n* Two", media_type: "text/markdown") }

      it "renders the content as HTML" do
        expect(subject.xpath_nodes("//ul/li/text()")).to contain_exactly("One", "Two")
      end

      context "and a translation" do
        let_create!(:translation, origin: object, content: "* Un\n* Du")

        it "renders the translation of the content" do
          expect(subject.xpath_nodes("//ul/li/text()")).to contain_exactly("Un", "Du")
        end
      end
    end

    context "given a name" do
      before_each { object.assign(name: "Foo Bar Baz") }

      it "renders the name" do
        expect(subject.xpath_nodes("//*[@class='extra text']//text()")).to have("Foo Bar Baz")
      end

      context "and a translation" do
        let_create!(:translation, origin: object, name: "Foo Bàr Bàz")

        it "renders the translation of the name" do
          expect(subject.xpath_nodes("//*[@class='extra text']//text()")).to have("Foo Bàr Bàz")
        end
      end
    end

    context "given a summary" do
      before_each { object.assign(summary: "<p>Foo Bar Baz</p>") }

      it "renders the summary as plain text" do
        expect(subject.xpath_nodes("//details/summary/text()")).to have("Foo Bar Baz\n")
      end

      context "and a translation" do
        let_create!(:translation, origin: object, summary: "<p>Foo Bàr Bàz</p>")

        it "renders the translation of the summary as plain text" do
          expect(subject.xpath_nodes("//details/summary/text()")).to have("Foo Bàr Bàz\n")
        end
      end
    end

    context "given an attachment" do
      let(attachment) { ActivityPub::Object::Attachment.new(url: "http://remote/foo.jpg", media_type: "image/jpeg") }

      before_each { object.assign(attachments: [attachment]) }

      it "renders the attachment" do
        expect(subject.xpath_nodes("//img/@src")).to have("http://remote/foo.jpg")
      end
    end

    # translation

    def_mock Ktistec::Translator

    it "does not render a button to translate the content" do
      expect(subject.xpath_nodes("//button/text()")).not_to have("Translate")
    end

    it "does not render a button to clear the translation" do
      expect(subject.xpath_nodes("//button/text()")).not_to have("Clear")
    end

    context "when authenticated" do
      sign_in(as: account.username)

      it "does not render a button to translate the content" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Translate")
      end

      it "does not render a button to clear the translation" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Clear")
      end

      context "given a translator" do
        let(translator) { mock(Ktistec::Translator) }

        before_each { ::Ktistec.set_translator(translator) }
        after_each { ::Ktistec.clear_translator }

        it "does not render a button to translate the content" do
          expect(subject.xpath_nodes("//button/text()")).not_to have("Translate")
        end

        context "and an account and an object with the same primary language" do
          before_each do
            Global.account.not_nil!.language = "en-US"
            object.language = "en-GB"
          end

          it "does not render a button to translate the content" do
            expect(subject.xpath_nodes("//button/text()")).not_to have("Translate")
          end
        end

        context "and an account and an object with different languages" do
          before_each do
            Global.account.not_nil!.language = "fr"
            object.language = "en"
          end

          it "renders a button to translate the content" do
            expect(subject.xpath_nodes("//button/text()")).to have("Translate")
          end
        end
      end

      context "given a translation" do
        let_create!(:translation, origin: object)

        it "renders a button to clear the translation" do
          expect(subject.xpath_nodes("//button/text()")).to have("Clear")
        end
      end
    end

    # threads

    it "does not render a back link to the parent" do
      expect(subject.xpath_nodes("//a[contains(@class,'in-reply-to')]")).to be_empty
    end

    context "given a reply" do
      before_each { object.assign(in_reply_to: original).save }

      it "does not render a back link to the parent" do
        expect(subject.xpath_nodes("//a[contains(@class,'in-reply-to')]")).to be_empty
      end
    end

    it "does not render a button to the threaded conversation" do
      object.assign(in_reply_to: original).save
      expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
    end

    it "does not render a button to the threaded conversation" do
      original.assign(in_reply_to: object).save
      expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
    end

    it "does not render a button to the threaded conversation" do
      object.assign(in_reply_to_iri: "not dereferenced link")
      expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
    end

    context "when authenticated" do
      sign_in(as: account.username)

      pre_condition { expect(object.draft?).to be_false }

      it "renders a button to the threaded conversation" do
        object.assign(in_reply_to: original).save
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end

      it "renders a button to the threaded conversation" do
        original.assign(in_reply_to: object).save
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end

      it "renders a button to the threaded conversation" do
        object.assign(in_reply_to_iri: "not dereferenced link")
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end

      context "when viewing a thread" do
        let(for_thread) { [original] }

        it "does not render a back link to the parent" do
          expect(subject.xpath_nodes("//a[contains(@class,'in-reply-to')]")).to be_empty
        end

        context "given a reply" do
          before_each { object.assign(in_reply_to: original).save }

          it "renders a link back to the parent in thread view" do
            expect(subject.xpath_nodes("//a[contains(@class,'in-reply-to')]/@href").map(&.text)).
              to contain_exactly("#object-#{original.id}")
          end

          it "renders a link back to the parent in thread view" do
            expect(subject.xpath_nodes("//a[contains(@class,'in-reply-to')]/@title").map(&.text)).
              to contain_exactly("@remote")
          end
        end

        it "does not render a button to the threaded conversation" do
          object.assign(in_reply_to: original).save
          expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
        end

        it "does not render a button to the threaded conversation" do
          original.assign(in_reply_to: object).save
          expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
        end

        it "does not render a button to the threaded conversation" do
          object.assign(in_reply_to_iri: "not dereferenced link")
          expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
        end
      end

      it "does not render a button to the threaded conversation" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
      end

      context "when viewing details" do
        let(with_detail) { true }

        it "renders a button to the threaded conversation" do
          expect(subject.xpath_nodes("//button/text()")).to have("Thread")
        end
      end

      context "given hashtags with the same name" do
        let(with_detail) { true }

        before_each do
          object.assign(
            hashtags: [
              Factory.build(:hashtag, name: "bar"),
              Factory.build(:hashtag, name: "bar")
            ]
          )
        end

        it "renders one hashtag" do
          expect(subject.xpath_nodes("//div[contains(@class,'labels')]/a[contains(@class,'label')]/text()"))
            .to contain_exactly("#bar")
        end
      end

      context "given mentions with the same name" do
        let(with_detail) { true }

        before_each do
          object.assign(
            mentions: [
              Factory.build(:mention, name: "bar@one.com"),
              Factory.build(:mention, name: "bar@one.com")
            ]
          )
        end

        it "renders one mention" do
          expect(subject.xpath_nodes("//div[contains(@class,'labels')]/a[contains(@class,'label')]/text()"))
            .to contain_exactly("@bar")
        end
      end

      context "given mentions with different names but the same handle" do
        let(with_detail) { true }

        before_each do
          object.assign(
            mentions: [
              Factory.build(:mention, name: "bar@one.com"),
              Factory.build(:mention, name: "bar@two.com")
            ]
          )
        end

        it "renders two mentions" do
          expect(subject.xpath_nodes("//div[contains(@class,'labels')]/a[contains(@class,'label')]/text()"))
            .to contain_exactly("@bar@one.com", "@bar@two.com")
        end
      end

      context "given mentions with different names" do
        let(with_detail) { true }

        before_each do
          object.assign(
            mentions: [
              Factory.build(:mention, name: "foo@one.com"),
              Factory.build(:mention, name: "bar@two.com")
            ]
          )
        end

        it "renders two mentions" do
          expect(subject.xpath_nodes("//div[contains(@class,'labels')]/a[contains(@class,'label')]/text()"))
            .to contain_exactly("@foo", "@bar")
        end
      end
    end

    context "if approved" do
      before_each { actor.approve(original.save) }

      pre_condition { expect(object.draft?).to be_false }

      it "renders a button to the threaded conversation" do
        object.assign(in_reply_to: original).save
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end

      it "renders a button to the threaded conversation" do
        original.assign(in_reply_to: object).save
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end
    end

    # drafts

    context "when is draft" do
      before_each { object.assign(published: nil).save }

      pre_condition { expect(object.draft?).to be_true }

      it "does not render a button to edit" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Edit")
      end

      context "when authenticated" do
        sign_in(as: account.username)

        it "does not render a button to reply" do
          expect(subject.xpath_nodes("//button/text()")).not_to have("Reply")
        end

        it "does not render a button to like" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Like")
        end

        it "does not render a button to share" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Share")
        end

        it "renders a button to delete" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Delete")
        end

        it "renders a button to edit" do
          expect(subject.xpath_nodes("//button/text()")).to have("Edit")
        end
      end
    end

    # deleted

    context "when author is deleted" do
      before_each { author.delete! }

      it "indicates the author is deleted" do
        expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is deleted/)
      end

      context "when authenticated" do
        sign_in

        it "indicates the author is deleted" do
          expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is deleted/)
        end
      end
    end

    context "given an author that is not the actor" do
      let_create(:actor, named: author)

      context "when author is deleted" do
        before_each { author.delete! }

        it "indicates the author is deleted" do
          expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is deleted/)
        end

        context "when authenticated" do
          sign_in

          it "indicates the author is deleted" do
            expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is deleted/)
          end
        end
      end

      context "when actor is deleted" do
        before_each { actor.delete! }

        it "indicates the actor is deleted" do
          expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is deleted/)
        end

        context "when authenticated" do
          sign_in

          it "indicates the actor is deleted" do
            expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is deleted/)
          end
        end
      end
    end

    context "when object is deleted" do
      before_each { object.delete! }

      it "indicates the object is deleted" do
        expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/This content is deleted/)
      end
    end

    # blocked

    context "when author is blocked" do
      before_each { author.block! }

      it "indicates the author is blocked" do
        expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is blocked/)
      end

      context "when authenticated" do
        sign_in

        it "indicates the author is blocked" do
          expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is blocked/)
        end
      end
    end

    context "given an author that is not the actor" do
      let_create(:actor, named: author)

      context "when author is blocked" do
        before_each { author.block! }

        it "indicates the author is blocked" do
          expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is blocked/)
        end

        context "when authenticated" do
          sign_in

          it "indicates the author is blocked" do
            expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is blocked/)
          end
        end
      end

      context "when actor is blocked" do
        before_each { actor.block! }

        it "indicates the actor is blocked" do
          expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is blocked/)
        end

        context "when authenticated" do
          sign_in

          it "indicates the actor is blocked" do
            expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/actor is blocked/)
          end
        end
      end
    end

    context "when object is blocked" do
      before_each { object.block! }

      it "indicates the object is blocked" do
        expect(subject.xpath_nodes("//div[contains(@class,'extra text')]/em/text()")).to have(/This content is blocked/)
      end
    end

    # blocking/unblocking

    it "does not render a button to block" do
      expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
    end

    it "does not render a button to unblock" do
      expect(subject.xpath_nodes("//button/text()")).not_to have("Unblock")
    end

    context "when is remote" do
      let_create!(:object, published: Time.utc)
      let(author) { object.attributed_to }

      pre_condition { expect(object.local?).to be_false }

      it "does not render a button to block" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
      end

      it "does not render a button to unblock" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Unblock")
      end

      context "when authenticated" do
        sign_in(as: account.username)

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button/text()")).to have("Block")
        end

        it "does not render a button to unblock" do
          expect(subject.xpath_nodes("//button/text()")).not_to have("Unblock")
        end

        context "if object is blocked" do
          before_each { object.block! }

          it "does not render a button to block" do
            expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
          end

          it "renders a button to unblock" do
            expect(subject.xpath_nodes("//button/text()")).to have("Unblock")
          end
        end

        context "and object has been announced" do
          let_create!(:announce, actor: actor, object: object)

          it "does not render a button to block" do
            expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
          end
        end

        context "and object has been liked" do
          let_create!(:like, actor: actor, object: object)

          it "does not render a button to block" do
            expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
          end
        end
      end
    end

    # approving/unapproving

    context "when in reply to a post by the account's actor" do
      let(for_thread) { [original] }

      before_each do
        original.assign(attributed_to: account.actor).save
        object.assign(in_reply_to: original).save
      end

      it "does not render a checkbox" do
        actor.unapprove(object)
        expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']")).to be_empty
      end

      it "does not render a checkbox" do
        actor.approve(object)
        expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']")).to be_empty
      end

      context "when authenticated" do
        sign_in(as: account.username)

        it "renders a checkbox" do
          actor.unapprove(object)
          expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']")).not_to be_empty
        end

        it "renders a checkbox" do
          actor.approve(object)
          expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']")).not_to be_empty
        end

        it "expects the checkbox not to be checked" do
          actor.unapprove(object)
          expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']/@checked")).to be_empty
        end

        it "expects the checkbox to be checked" do
          actor.approve(object)
          expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']/@checked")).not_to be_empty
        end
      end
    end

    # hosting

    context "if object content is externally hosted" do
      class ExternalObject < ActivityPub::Object
        # objects are externally hosted by default
      end

      let(object) { ExternalObject.new(name: "Foo Bar Baz") }

      pre_condition { expect(object.external?).to be_true }

      it "renders link to the external content" do
        expect(subject.xpath_nodes("//a/strong/text()")).to have("Foo Bar Baz")
      end
    end

    context "if object content is not externally hosted" do
      let_create!(:note, named: :object, name: "Foo Bar Baz")

      pre_condition { expect(object.external?).to be_false }

      it "renders name of the object" do
        expect(subject.xpath_nodes("//strong/text()")).to have("Foo Bar Baz")
      end
    end
  end

  describe "object_partial" do
    let(env) { env_factory("GET", "/object") }

    subject do
      begin
        XML.parse_html(Ktistec::ViewHelper.object_partial(env, object, activity: activity, with_detail: with_detail, for_thread: for_thread))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let_create!(:object)
    let_build(:object, named: :original)

    let_build(:like, named: :activity, object: object)

    let(with_detail) { false }
    let(for_thread) { nil }

    it "renders the activity type as a class" do
      expect(subject.xpath_nodes("//*[contains(@class,'event activity-like')]")).not_to be_empty
    end

    context "when with detail" do
      let(with_detail) { true }

      it "renders the activity type as a class" do
        expect(subject.xpath_nodes("//*[contains(@class,'event activity-like')]")).not_to be_empty
      end
    end

    context "when in a thread" do
      let(for_thread) { [original] }

      it "renders the activity type as a class" do
        expect(subject.xpath_nodes("//*[contains(@class,'event activity-like')]")).not_to be_empty
      end
    end

    context "with multiple state classes" do
      let_create!(:object, sensitive: true, replies_count: 2_i64)
      let_create!(:mention, subject: object, name: "testuser")

      it "contains expected class values" do
        class_attr = subject.xpath_nodes("//*[contains(@class,'event')]/@class").first.content
        classes = class_attr.split(/\s+/)
        expect(classes).to contain_exactly(
          "event",
          "activity-like",
          "actor-actor",
          "object-object",
          "is-sensitive",
          "has-replies",
          "visibility-public",
        ).in_any_order
      end
    end
  end

  describe "object.json.ecr" do
    let(env) { env_factory("GET", "/object") }

    subject do
      JSON.parse(render "src/views/partials/object.json.ecr")
    end

    describe "Question with oneOf" do
      let_build(
        :actor, named: :author,
      )
      let_build(
        :question, named: :object,
        attributed_to: author,
        published: Time.utc,
      )
      let_create!(
        :poll,
        question: object,
        options: [
          Poll::Option.new("Option 1", 5),
          Poll::Option.new("Option 2", 3),
        ],
        multiple_choice: false,
        voters_count: 8,
        closed_at: 1.day.from_now,
      )
      let(recursive) { false }

      it "includes `oneOf`" do
        expect(subject["oneOf"]).not_to be_nil
      end

      it "does not include `anyOf`" do
        expect(subject["anyOf"]?).to be_nil
      end

      it "includes correct number of options" do
        expect(subject["oneOf"].as_a.size).to eq(2)
      end

      it "includes option names" do
        expect(subject["oneOf"][0]["name"]).to eq("Option 1")
        expect(subject["oneOf"][1]["name"]).to eq("Option 2")
      end

      it "includes vote counts" do
        expect(subject["oneOf"][0]["replies"]["totalItems"]).to eq(5)
        expect(subject["oneOf"][1]["replies"]["totalItems"]).to eq(3)
      end

      it "includes `votersCount`" do
        expect(subject["votersCount"]).to eq(8)
      end

      it "has matching `endTime` and `closed` values" do
        expect(subject["endTime"]).to eq(subject["closed"])
      end
    end

    describe "Question with anyOf" do
      let_build(
        :actor, named: :author,
      )
      let_build(
        :question, named: :object,
        attributed_to: author,
        published: Time.utc,
      )
      let_create!(
        :poll,
        question: object,
        options: [
          Poll::Option.new("Choice A", 7),
          Poll::Option.new("Choice B", 2),
        ],
        multiple_choice: true,
        voters_count: 15,
        closed_at: 2.days.from_now,
      )
      let(recursive) { false }

      it "includes `anyOf`" do
        expect(subject["anyOf"]).not_to be_nil
      end

      it "does not include `oneOf`" do
        expect(subject["oneOf"]?).to be_nil
      end

      it "includes correct number of options" do
        expect(subject["anyOf"].as_a.size).to eq(2)
      end

      it "includes option names" do
        expect(subject["anyOf"][0]["name"]).to eq("Choice A")
        expect(subject["anyOf"][1]["name"]).to eq("Choice B")
      end

      it "includes vote counts" do
        expect(subject["anyOf"][0]["replies"]["totalItems"]).to eq(7)
        expect(subject["anyOf"][1]["replies"]["totalItems"]).to eq(2)
      end

      it "includes `votersCount`" do
        expect(subject["votersCount"]).to eq(15)
      end

      it "has matching `endTime` and `closed` values" do
        expect(subject["endTime"]).to eq(subject["closed"])
      end
    end

    context "given a poll" do
      let_build(
        :actor, named: :author,
      )
      let_build(
        :question, named: :object,
        attributed_to: author,
        published: Time.utc,
      )
      let_create!(
        :poll,
        question: object,
        options: [
          Poll::Option.new("Yes", 0),
          Poll::Option.new("No", 0),
        ],
      )
      let(recursive) { false }

      it "does not include `votersCount`" do
        expect(subject["votersCount"]?).to be_nil
      end

      it "does not include `endTime`" do
        expect(subject["endTime"]?).to be_nil
      end

      it "does not include `closed`" do
        expect(subject["closed"]?).to be_nil
      end
    end
  end
end
