require "../../src/models/activity_pub/object/note"
require "../../src/models/activity_pub/object/video"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/announce"
require "../../src/models/activity_pub/activity/like"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "partials" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "collection.json.ecr" do
    let(collection) do
      Ktistec::Util::PaginatedArray{
        Factory.build(:object, iri: "foo"),
        Factory.build(:object, iri: "bar")
      }
    end

    let(env) { env_factory("GET", "/collection#{query}") }

    subject { JSON.parse(render "./src/views/partials/collection.json.ecr") }

    context "when paginated" do
      let(query) { "?page=1&size=2" }

      it "renders a collection page" do
        expect(subject.dig("type")).to eq("OrderedCollectionPage")
      end

      it "contains the id of the collection page" do
        expect(subject.dig("id")).to eq("#{Ktistec.host}/collection?page=1&size=2")
      end

      it "contains a page of items" do
        expect(subject.dig("orderedItems").as_a).to contain_exactly("foo", "bar")
      end

      it "does not contain navigation links" do
        expect(subject.dig?("prev")).to be_nil
        expect(subject.dig?("next")).to be_nil
      end

      context "and on the second page" do
        let(query) { "?page=2&size=2" }

        it "contains a link to the previous page" do
          expect(subject.dig?("prev")).to eq("#{Ktistec.host}/collection?page=1&size=2")
        end
      end

      context "and contains more" do
        before_each { collection.more = true }

        it "contains a link to the next page" do
          expect(subject.dig?("next")).to eq("#{Ktistec.host}/collection?page=2&size=2")
        end
      end
    end

    context "when not paginated" do
      let(query) { "" }

      it "renders a collection" do
        expect(subject.dig("type")).to eq("OrderedCollection")
      end

      it "contains the id of the collection" do
        expect(subject.dig("id")).to eq("#{Ktistec.host}/collection")
      end

      it "does not contain any items" do
        expect(subject.dig?("orderedItems")).to be_nil
      end

      it "contains the first collection page" do
        expect(subject.dig("first", "type")).to eq("OrderedCollectionPage")
      end

      it "contains the first collection page" do
        expect(subject.dig("first", "id")).to eq("#{Ktistec.host}/collection?page=1")
      end

      it "contains the first collection page of items" do
        expect(subject.dig("first", "orderedItems").as_a).to contain_exactly("foo", "bar")
      end

      it "does not contain navigation links" do
        expect(subject.dig?("first", "prev")).to be_nil
        expect(subject.dig?("first", "next")).to be_nil
      end

      context "and contains more" do
        before_each { collection.more = true }

        it "contains a link to the next page" do
          expect(subject.dig?("first", "next")).to eq("#{Ktistec.host}/collection?page=2")
        end
      end
    end
  end

  macro follow(from, to, confirmed = true)
    let_create!(
      :follow,
      actor: {{from}},
      object: {{to}}
    )
    let_create!(
      :follow_relationship,
      actor: {{from}},
      object: {{to}},
      confirmed: {{confirmed}}
    )
  end

  describe "actor-panel.html.slang" do
    let_create(:actor)

    let(env) { env_factory("GET", "/actor") }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/actor-panel.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if anonymous" do
      it "does not render buttons" do
        expect(subject.xpath_nodes("//button")).to be_empty
      end

      context "and actor is local" do
        before_each { actor.assign(iri: "https://test.test/actors/foo_bar").save }

        it "renders a button to remote follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end
      end
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      context "if account actor is actor" do
        let(actor) { account.actor }

        it "does not render buttons" do
          expect(subject.xpath_nodes("//button")).to be_empty
        end
      end

      context "if following actor" do
        follow(account.actor, actor)

        it "renders a button to unfollow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Unfollow")
        end

        it "does not render a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Block")
        end
      end

      it "renders a button to follow" do
        expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
      end

      context "if actor is blocked" do
        before_each { actor.block }

        it "renders a button to unblock" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Unblock")
        end

        it "does not render a button to follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Follow")
        end

        it "renders a blocked message segment" do
          expect(subject.xpath_nodes("//div[contains(@class,'segment')][contains(@class,'blocked')]")).not_to be_empty
        end
      end

      it "does not render a blocked message segment" do
        expect(subject.xpath_nodes("//div[contains(@class,'segment')][contains(@class,'blocked')]")).to be_empty
      end

      it "renders a button to block" do
        expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
      end
    end
  end

  describe "actor-card.html.slang" do
    let_create(:actor)

    let(env) { env_factory("GET", "/actors/foo_bar") }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/actor-card.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if anonymous" do
      it "does not render buttons" do
        expect(subject.xpath_nodes("//buttons")).to be_empty
      end

      context "and actor is local" do
        before_each { actor.assign(iri: "https://test.test/actors/foo_bar").save }

        it "renders a button to remote follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end
      end
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      context "if account actor is actor" do
        let(actor) { account.actor }

        it "does not render buttons" do
          expect(subject.xpath_nodes("//button")).to be_empty
        end
      end

      # on a page of the actors the actor is following, the actor
      # expects to focus on actions regarding their decision to follow
      # those actors, so don't present accept/reject actions, even if
      # the other actor is a follower.

      context "and on a page of actors the actor is following" do
        let(env) { env_factory("GET", "/actors/foo_bar/following") }

        follow(actor, account.actor, confirmed: false)

        context "if already following" do
          follow(account.actor, actor)

          it "renders a button to unfollow" do
            expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Unfollow")
          end
        end

        it "renders a button to follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end
      end

      # otherwise, on a page of the actors who are followers of the actor...

      context "having not accepted or rejected a follow" do
        let(env) { env_factory("GET", "/actors/foo_bar/followers") }

        follow(actor, account.actor, confirmed: false)

        context "if following" do
          follow(account.actor, actor)

          it "renders a button to accept" do
            expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Accept")
          end

          it "renders a button to reject" do
            expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Reject")
          end

          it "renders a button to block" do
            expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
          end
        end

        it "renders a button to accept" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Accept")
        end

        it "renders a button to reject" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Reject")
        end

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
        end
      end

      context "having accepted or rejected a follow" do
        let(env) { env_factory("GET", "/actors/foo_bar/followers") }

        follow(actor, account.actor, confirmed: true)

        context "if following" do
          follow(account.actor, actor)

          it "renders a button to unfollow" do
            expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Unfollow")
          end

          it "does not render a button to block" do
            expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Block")
          end
        end

        it "renders a button to follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
        end
      end

      context "if following" do
        follow(account.actor, actor)

        it "renders a button to unfollow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Unfollow")
        end

        it "does not render a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Block")
        end
      end

      it "renders a button to follow" do
        expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
      end

      it "renders a button to block" do
        expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
      end
    end
  end

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

  describe "editor.html.slang" do
    let(env) { env_factory("GET", "/editor") }

    subject do
      XML.parse_html(render "./src/views/partials/editor.html.slang")
    end

    let_build(:object, local: true)

    context "if authenticated" do
      before_each { env.account = register }

      context "given a new object" do
        pre_condition { expect(object.new_record?).to be_true }

        it "renders an id" do
          expect(subject.xpath_nodes("//form/@id").first).to eq("object-new")
        end

        it "does not render an input with the object iri" do
          expect(subject.xpath_nodes("//input[@name='object']")).
            to be_empty
        end

        it "includes an input to save draft" do
          expect(subject.xpath_nodes("//input[@value='Save Draft']")).
            not_to be_empty
        end

        it "does not include a link to return to drafts" do
          expect(subject.xpath_nodes("//a[text()='To Drafts']")).
            to be_empty
        end
      end

      context "given a saved object" do
        before_each { object.save }

        pre_condition { expect(object.new_record?).to be_false }

        it "renders an id" do
          expect(subject.xpath_nodes("//form/@id").first).to eq("object-#{object.id}")
        end

        it "renders an input with the object iri" do
          expect(subject.xpath_nodes("//input[@name='object']")).
            not_to be_empty
        end
      end

      context "given a draft object" do
        before_each { object.save }

        pre_condition { expect(object.draft?).to be_true }

        it "includes an input to publish post" do
          expect(subject.xpath_nodes("//input[@value='Publish Post']")).
            not_to be_empty
        end

        it "includes an input to save draft" do
          expect(subject.xpath_nodes("//input[@value='Save Draft']")).
            not_to be_empty
        end

        it "includes a link to return to drafts" do
          expect(subject.xpath_nodes("//a[text()='To Drafts']")).
            not_to be_empty
        end
      end

      context "given a published object" do
        before_each { object.assign(published: Time.utc).save }

        pre_condition { expect(object.draft?).to be_false }

        it "includes an input to update post" do
          expect(subject.xpath_nodes("//input[@value='Update Post']")).
            not_to be_empty
        end

        it "does not include an input to save draft" do
          expect(subject.xpath_nodes("//input[@value='Save Draft']")).
            to be_empty
        end

        it "does not include a link to return to drafts" do
          expect(subject.xpath_nodes("//a[text()='To Drafts']")).
            to be_empty
        end
      end

      context "an object with errors" do
        before_each { object.errors["object"] = ["has errors"] }

        it "renders the error class" do
          expect(subject.xpath_nodes("//form/@class").first).to match(/\berror\b/)
        end
      end
    end
  end

  describe "reply.html.slang" do
    let(env) { env_factory("GET", "/object") }

    subject do
      begin
        XML.parse_html(render "./src/views/objects/reply.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      let_build(:actor, named: :actor1, username: "actor1")
      let_build(:actor, named: :actor2, username: "actor2")
      let_build(:object, named: :original, attributed_to: account.actor)
      let_build(:object, named: :object1, attributed_to: actor1, in_reply_to: original)
      let_build(:object, named: :object2, attributed_to: actor2, in_reply_to: object1)

      let!(object) { object2.save }

      it "prepopulates editor with mentions" do
        expect(subject.xpath_nodes("//input[@name='content']/@value").first).
          to eq("@#{actor2.account_uri} @#{actor1.account_uri} ")
      end
    end
  end
end
