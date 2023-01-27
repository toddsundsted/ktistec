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

  describe "object.html.slang" do
    let(activity) { nil }

    let(for_thread) { nil }

    let(env) { env_factory("GET", "/object") }

    subject do
      begin
        XML.parse_html(object_partial(env, object, activity: activity, for_thread: for_thread))
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    let(account) { register }
    let(actor) { account.actor }

    let_create!(:object, attributed_to: actor, published: Time.utc)
    let_build(:object, named: :original)

    it "does not render a button to the threaded conversation" do
      object.assign(in_reply_to: original, attributed_to: actor).save
      expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
    end

    it "does not render a button to the threaded conversation" do
      original.assign(in_reply_to: object, attributed_to: actor).save
      expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
    end

    context "if approved" do
      before_each do
        actor.approve(original.save)
      end

      it "renders a button to the threaded conversation" do
        object.assign(in_reply_to: original, attributed_to: actor).save
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end

      it "renders a button to the threaded conversation" do
        original.assign(in_reply_to: object, attributed_to: actor).save
        expect(subject.xpath_nodes("//button/text()")).to have("Thread")
      end
    end

    context "given an associated activity" do
      let_build(:like, named: :activity, actor: actor, object: object)

      it "renders the activity type as a class" do
        expect(subject.xpath_nodes("//*[contains(@class,'event activity-like')]")).not_to be_empty
      end

      context "when a reply" do
        let(for_thread) { [original] }

        it "renders the activity type as a class" do
          expect(subject.xpath_nodes("//*[contains(@class,'event activity-like')]")).not_to be_empty
        end
      end
    end

    context "if external" do
      let_create!(:video, named: :object, name: "Foo Bar Baz")

      pre_condition { expect(object.external?).to be_true }

      it "renders a link to the external object" do
        expect(subject.xpath_nodes("//a/strong/text()")).to have("Foo Bar Baz")
      end
    end

    context "if not external" do
      let_create!(:note, named: :object, name: "Foo Bar Baz")

      pre_condition { expect(object.external?).to be_false }

      it "renders the name of the object" do
        expect(subject.xpath_nodes("//strong/text()")).to have("Foo Bar Baz")
      end
    end

    context "if authenticated" do
      before_each { env.account = account }

      it "does not render a button to block" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
      end

      it "does not render a button to unblock" do
        expect(subject.xpath_nodes("//button/text()")).not_to have("Unblock")
      end

      context "for approvals" do
        context "on a page of threaded replies" do
          let(env) { env_factory("GET", "/thread") }

          it "does not render a checkbox to approve" do
            actor.unapprove(object)
            expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']")).to be_empty
          end

          it "does not render a checkbox to unapprove" do
            actor.approve(object)
            expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']")).to be_empty
          end

          context "unless in reply to a post by the account's actor" do
            let(for_thread) { [original] }

            before_each do
              original.assign(attributed_to: account.actor).save
              object.assign(in_reply_to: original).save
            end

            it "renders a checkbox to approve" do
              actor.unapprove(object)
              expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']/@checked")).to be_empty
            end

            it "renders a checkbox to unapprove" do
              actor.approve(object)
              expect(subject.xpath_nodes("//input[@type='checkbox'][@name='public']/@checked")).not_to be_empty
            end
          end
        end
      end

      context "and given a draft" do
        before_each { object.assign(published: nil).save }

        pre_condition { expect(object.draft?).to be_true }

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

      context "and is published" do
        before_each { object.assign(published: Time.utc).save }

        pre_condition { expect(object.draft?).to be_false }

        it "does not render a button to the threaded conversation" do
          expect(subject.xpath_nodes("//button/text()")).not_to have("Thread")
        end

        it "renders a button to the threaded conversation" do
          object.assign(in_reply_to: original, attributed_to: account.actor).save
          expect(subject.xpath_nodes("//button/text()")).to have("Thread")
        end

        it "renders a button to the threaded conversation" do
          original.assign(in_reply_to: object, attributed_to: account.actor).save
          expect(subject.xpath_nodes("//button/text()")).to have("Thread")
        end
      end

      context "and is remote" do
        let_create!(:object, published: Time.utc)

        pre_condition { expect(object.local?).to be_false }

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

        context "and object is announced" do
          let_create!(:announce, actor: actor, object: object)

          it "does not render a button to block" do
            expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
          end
        end

        context "and object is liked" do
          let_create!(:like, actor: actor, object: object)

          it "does not render a button to block" do
            expect(subject.xpath_nodes("//button/text()")).not_to have("Block")
          end
        end
      end
    end
  end
end
