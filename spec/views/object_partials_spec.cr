require "../../src/models/activity_pub/object/note"
require "../../src/models/activity_pub/object/video"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/like"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "object partials" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "label.html.slang" do
    subject do
      begin
        XML.parse_html(render "./src/views/partials/object/label.html.slang")
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
    end

    context "the actor is not the author" do
      let_build(:actor, named: author, icon: random_string)

      it "renders two profile icons" do
        expect(subject.xpath_nodes("//img/@src")).to contain_exactly(author.icon, actor.icon)
      end
    end
  end

  describe "content.html.slang" do
    let(env) { env_factory("GET", "/object") }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/object/content.html.slang")
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

    context "given HTML content" do
      before_each { object.assign(content: "<ul><li>One</li><li>Two</li></ul>", media_type: "text/html") }

      it "renders the content as is" do
        expect(subject.xpath_nodes("//ul/li/text()")).to contain_exactly("One", "Two")
      end
    end

    context "given Markdown content" do
      before_each { object.assign(content: "* One\n* Two", media_type: "text/markdown") }

      it "renders the content as HTML" do
        expect(subject.xpath_nodes("//ul/li/text()")).to contain_exactly("One", "Two")
      end
    end

    # threads

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
      before_each { env.account = account }

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
        before_each { env.account = account }

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
        before_each { env.account = account }

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button/text()")).to have("Block")
        end

        it "does not render a button to unblock" do
          expect(subject.xpath_nodes("//button/text()")).not_to have("Unblock")
        end

        context "if object is blocked" do
          before_each { object.block }

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
        before_each { env.account = account }

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
      let_create!(:video, named: :object, name: "Foo Bar Baz")

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
        XML.parse_html(object_partial(env, object, activity: activity, with_detail: with_detail, for_thread: for_thread))
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
  end
end
