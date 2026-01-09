require "../../src/models/activity_pub/activity/follow"
require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "partials" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  describe "collection.json.ecr" do
    let_build(:object, named: foo, iri: "foo")
    let_build(:object, named: bar, iri: "bar")

    let(collection) do
      Ktistec::Util::PaginatedArray{foo, bar}
    end

    let(env) { make_env("GET", "/collection#{query}") }

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

  macro follow(from, to, confirmed = true, follow_activity = nil, follow_relationship = nil)
    let_create!(
      :follow,
      named: {{follow_activity}},
      actor: {{from}},
      object: {{to}}
    )
    let_create!(
      :follow_relationship,
      named: {{follow_relationship}},
      actor: {{from}},
      object: {{to}},
      confirmed: {{confirmed}}
    )
  end

  describe "tag_page_tag_controls.html.slang" do
    sign_in

    let(hashtag) { "foobar" }

    let(env) { make_env("GET", "/tags/#{hashtag}") }

    let(task) { nil }
    let(follow) { nil }
    let(count) { 0 }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/tag_page_tag_controls.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    it "renders a follow and a fetch button" do
      expect(subject.xpath_nodes("//*[contains(@id,'tag_page_tag_controls')]//button[@type='submit']"))
        .to contain_exactly("Follow", "Fetch Once")
    end

    def_double :follow, destroyed?: false

    context "given a follow" do
      let(follow) { new_double(:follow) }

      it "renders an unfollow button" do
        expect(subject.xpath_nodes("//*[contains(@id,'tag_page_tag_controls')]//button[@type='submit']"))
          .to contain_exactly("Unfollow")
      end
    end

    context "given a destroyed follow" do
      let(follow) { new_double(:follow, destroyed?: true) }

      it "does not render an unfollow button" do
        expect(subject.xpath_nodes("//*[contains(@id,'tag_page_tag_controls')]//button[@type='submit']"))
          .not_to contain("Unfollow")
      end
    end

    def_double :task, complete: false, running: true, backtrace: nil

    context "given a task" do
      let(task) { new_double(:task) }

      it "renders a cancel button" do
        expect(subject.xpath_nodes("//*[contains(@id,'tag_page_tag_controls')]//button[@type='submit']"))
          .to contain_exactly("Cancel")
      end
    end

    context "given a complete task" do
      let(task) { new_double(:task, complete: true) }

      it "does not render a cancel button" do
        expect(subject.xpath_nodes("//*[contains(@id,'tag_page_tag_controls')]//button[@type='submit']"))
          .not_to contain("Cancel")
      end
    end
  end

  describe "thread_page_thread_controls.html.slang" do
    sign_in

    let_create(:object)

    let(env) { make_env("GET", "/remote/objects/#{object.id}/thread") }

    let(:thread) { object.thread(for_actor: object.attributed_to) }

    let(task) { nil }
    let(follow) { nil }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/thread_page_thread_controls.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    it "renders a follow and a fetch button" do
      expect(subject.xpath_nodes("//*[contains(@id,'thread_page_thread_controls')]//button[@type='submit']"))
        .to contain_exactly("Follow", "Fetch Once")
    end

    def_double :follow, destroyed?: false

    context "given a follow" do
      let(follow) { new_double(:follow) }

      it "renders an unfollow button" do
        expect(subject.xpath_nodes("//*[contains(@id,'thread_page_thread_controls')]//button[@type='submit']"))
          .to contain_exactly("Unfollow")
      end
    end

    context "given a destroyed follow" do
      let(follow) { new_double(:follow, destroyed?: true) }

      it "does not render an unfollow button" do
        expect(subject.xpath_nodes("//*[contains(@id,'thread_page_thread_controls')]//button[@type='submit']"))
          .not_to contain("Unfollow")
      end
    end

    def_double :task, complete: false, running: true, backtrace: nil

    context "given a task" do
      let(task) { new_double(:task) }

      it "renders a cancel button" do
        expect(subject.xpath_nodes("//*[contains(@id,'thread_page_thread_controls')]//button[@type='submit']"))
          .to contain_exactly("Cancel")
      end
    end

    context "given a complete task" do
      let(task) { new_double(:task, complete: true) }

      it "does not render a cancel button" do
        expect(subject.xpath_nodes("//*[contains(@id,'thread_page_thread_controls')]//button[@type='submit']"))
          .not_to contain("Cancel")
      end
    end

    context "given a thread with <10 posts" do
      let(:thread) { Array.new(5) { object } }

      it "does not render the full analysis link" do
        expect(subject.xpath_nodes("//a[contains(text(),'full analysis')]")).to be_empty
      end
    end

    context "given a thread with 10+ posts" do
      let(:thread) { Array.new(15) { object } }

      it "renders the full analysis link" do
        expect(subject.xpath_nodes("//a[contains(text(),'full analysis')]")).not_to be_empty
      end

      context "given a fetch task" do
        let(task) { new_double(:task, running: true, complete: false) }

        it "does not render the full analysis link" do
          expect(subject.xpath_nodes("//a[contains(text(),'full analysis')]")).to be_empty
        end

        context "that is not running" do
          let(task) { new_double(:task, running: false, complete: true) }

          it "renders the full analysis link" do
            expect(subject.xpath_nodes("//a[contains(text(),'full analysis')]")).not_to be_empty
          end
        end
      end
    end
  end

  describe "actor-panel.html.slang" do
    let_create(:actor)

    let(env) { make_env("GET", "/actor") }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/actor-panel.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if anonymous" do
      it "does not render an internal link to the actor" do
        expect(subject.xpath_nodes("//a/@href")).not_to have("/remote/actors/#{actor.id}")
      end

      it "does not render buttons" do
        expect(subject.xpath_nodes("//button")).to be_empty
      end

      context "and actor is local" do
        before_each { actor.assign(iri: "https://test.test/actors/foo_bar").save }

        it "renders a button to remote follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end
      end

      context "and actor is down" do
        before_each { actor.down! }

        it "does not render a down warning message" do
          expect(subject.xpath_nodes("//div[contains(@class,'message')][contains(@class,'warning')]//text()"))
            .to be_empty
        end
      end
    end

    context "if authenticated" do
      let(account) { register }

      sign_in(as: account.username)

      it "renders an internal link to the actor" do
        expect(subject.xpath_nodes("//a/@href")).to have("/remote/actors/#{actor.id}")
      end

      context "and account actor is actor" do
        let(actor) { account.actor }

        it "does not render buttons" do
          expect(subject.xpath_nodes("//button")).to be_empty
        end
      end

      context "and following actor" do
        follow(account.actor, actor, follow_activity: follow_activity, follow_relationship: follow_relationship)

        it "renders a button to unfollow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Unfollow")
        end

        it "does not render a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Block")
        end

        context "when follow request is pending" do
          before_each do
            follow_relationship.assign(confirmed: false).save
          end

          it "displays pending follow request status" do
            expect(subject.xpath_nodes("//div[contains(@class,'status')]/text()")).to have(/request .* pending/)
          end
        end

        context "when follow request was accepted" do
          let_create!(:accept, actor: actor, object: follow_activity)

          it "displays accepted follow request status with timestamp" do
            expect(subject.xpath_nodes("//div[contains(@class,'status')]/text()")).to have(/accepted .* ago/)
          end
        end

        context "when follow request was rejected" do
          let_create!(:reject, actor: actor, object: follow_activity)

          it "displays rejected follow request status with timestamp" do
            expect(subject.xpath_nodes("//div[contains(@class,'status')]/text()")).to have(/rejected .* ago/)
          end
        end
      end

      it "renders a button to follow" do
        expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
      end

      context "having not accepted or rejected a follow" do
        follow(actor, account.actor, confirmed: false)

        it "renders a button to accept" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Accept")
        end

        it "renders a button to reject" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Reject")
        end

        it "renders a button to follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
        end
      end

      context "having accepted a follow" do
        follow(actor, account.actor, confirmed: true, follow_activity: follow_activity)

        let_create!(:accept, actor: account.actor, object: follow_activity)

        it "does not render a button to accept" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Accept")
        end

        it "does not render a button to reject" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Reject")
        end

        it "renders a button to reject instead" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Reject Instead")
        end

        it "renders a button to follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
        end
      end

      context "having rejected a follow" do
        follow(actor, account.actor, confirmed: true, follow_activity: follow_activity)

        let_create!(:reject, actor: account.actor, object: follow_activity)

        it "does not render a button to accept" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Accept")
        end

        it "does not render a button to reject" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Reject")
        end

        it "does not render a button to reject instead" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).not_to have("Reject Instead")
        end

        it "renders a button to accept now" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Accept Instead")
        end

        it "renders a button to follow" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Follow")
        end

        it "renders a button to block" do
          expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Block")
        end
      end

      context "and actor is blocked" do
        before_each { actor.block! }

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

      it "renders a button to refresh" do
        expect(subject.xpath_nodes("//button[@type='submit']/text()")).to have("Refresh")
      end

      it "renders the last refresh time" do
        expect(subject.xpath_nodes("//div[contains(@class, 'status')]/text()")).to have(/refreshed/)
      end

      context "and actor is down" do
        before_each { actor.down! }

        it "renders a down warning message" do
          expect(subject.xpath_nodes("//div[contains(@class,'message')][contains(@class,'warning')]//text()"))
            .to have(/actor is marked as down/)
        end
      end
    end
  end

  describe "actor-card.html.slang" do
    let_create(:actor)

    let(env) { make_env("GET", "/actors/foo_bar") }

    subject do
      begin
        XML.parse_html(render "./src/views/partials/actor-card.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if anonymous" do
      it "does not render an internal link to the actor" do
        expect(subject.xpath_nodes("//a/@href")).not_to have("/remote/actors/#{actor.id}")
      end

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

      sign_in(as: account.username)

      it "renders an internal link to the actor" do
        expect(subject.xpath_nodes("//a/@href")).to have("/remote/actors/#{actor.id}")
      end

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
        let(env) { make_env("GET", "/actors/foo_bar/following") }

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
        let(env) { make_env("GET", "/actors/foo_bar/followers") }

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
        let(env) { make_env("GET", "/actors/foo_bar/followers") }

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

  def make_env(method, path, body)
    HTTP::Server::Context.new(
      HTTP::Request.new(method, path).tap do |request|
        request.headers["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = body
      end,
      HTTP::Server::Response.new(IO::Memory.new)
    )
  end

  describe "editor.html.slang" do
    let(env) { make_env("GET", "/editor") }

    subject do
      XML.parse_html(render "./src/views/partials/editor.html.slang")
    end

    let_build(:object, local: true)

    context "if authenticated" do
      let(account) { register }

      sign_in(as: account.username)

      context "given a new object" do
        pre_condition { expect(object.new_record?).to be_true }

        it "renders an id" do
          expect(subject.xpath_nodes("//form/@id").first).to eq("object-new")
        end

        it "does not render an input with the object iri" do
          expect(subject.xpath_nodes("//input[@name='object']"))
            .to be_empty
        end

        it "includes an input to create draft" do
          expect(subject.xpath_nodes("//button[text()='Create Draft']"))
            .not_to be_empty
        end

        it "does not include a link to return to drafts" do
          expect(subject.xpath_nodes("//a[text()='To Drafts']"))
            .to be_empty
        end

        it "uses the default language" do
          expect(subject.xpath_nodes("//input[@name='language']/@value").first).to eq("en")
        end

        context "if no default language is set" do
          before_each { Global.account.not_nil!.language = nil }

          it "does not render an input for language" do
            expect(subject.xpath_nodes("//input[@name='language']")).to be_empty
          end
        end

        context "given an assigned language" do
          before_each { object.assign(language: "fr") }

          it "uses the assigned language" do
            expect(subject.xpath_nodes("//input[@name='language']/@value").first).to eq("fr")
          end
        end
      end

      context "given a saved object" do
        before_each { object.save }

        pre_condition { expect(object.new_record?).to be_false }

        it "renders an id" do
          expect(subject.xpath_nodes("//form/@id").first).to eq("object-#{object.id}")
        end

        it "renders an input with the object iri" do
          expect(subject.xpath_nodes("//input[@name='object']/@value"))
            .to have(object.iri)
        end
      end

      context "given a reply" do
        let_build(:object, named: :original)
        let_build(:object, named: :intermediate, in_reply_to: original)

        before_each do
          original.attributed_to.username = "actor1"
          intermediate.attributed_to.username = "actor2"
          object.assign(in_reply_to: intermediate).save
        end

        it "renders an input with the replied to object's iri" do
          expect(subject.xpath_nodes("//input[@name='in-reply-to']/@value"))
            .to have(intermediate.iri)
        end

        it "prepopulates editor with mentions" do
          expect(subject.xpath_nodes("//textarea[@name='content']/text()").first)
            .to eq("@#{intermediate.attributed_to.handle} @#{original.attributed_to.handle} ")
        end

        it "does not render details" do
          expect(subject.xpath_nodes("//details")).to be_empty
        end

        it "includes an input to send reply" do
          expect(subject.xpath_nodes("//button[text()='Send Reply']"))
            .not_to be_empty
        end
      end

      context "given a self-reply" do
        let_build(:object, named: :original)

        before_each do
          original.attributed_to = account.actor
          object.assign(in_reply_to: original).save
        end

        it "does not self-mention" do
          expect(subject.xpath_nodes("//textarea[@name='content']/text()"))
            .to be_empty
        end
      end

      context "given a draft object" do
        before_each { object.save }

        pre_condition { expect(object.draft?).to be_true }

        it "includes an input to publish post" do
          expect(subject.xpath_nodes("//button[text()='Publish Post']"))
            .not_to be_empty
        end

        it "includes an input to update draft" do
          expect(subject.xpath_nodes("//button[text()='Update Draft']"))
            .not_to be_empty
        end

        it "includes a link to return to drafts" do
          expect(subject.xpath_nodes("//a[text()='To Drafts']"))
            .not_to be_empty
        end
      end

      context "given a published object" do
        before_each { object.assign(published: Time.utc).save }

        pre_condition { expect(object.draft?).to be_false }

        it "includes an input to update post" do
          expect(subject.xpath_nodes("//button[text()='Update Post']"))
            .not_to be_empty
        end

        it "does not include an input to save draft" do
          expect(subject.xpath_nodes("//button[contains(text(),'Draft')]"))
            .to be_empty
        end

        it "does not include a link to return to drafts" do
          expect(subject.xpath_nodes("//a[text()='To Drafts']"))
            .to be_empty
        end
      end

      context "visibility" do
        PUBLIC_PATH  = "//form//input[@type='radio'][@value='public'][@checked]"
        PRIVATE_PATH = "//form//input[@type='radio'][@value='private'][@checked]"
        DIRECT_PATH  = "//form//input[@type='radio'][@value='direct'][@checked]"

        it "renders the public checkbox as checked" do
          expect(subject.xpath_nodes(PUBLIC_PATH)).not_to be_empty
          expect(subject.xpath_nodes(PRIVATE_PATH)).to be_empty
          expect(subject.xpath_nodes(DIRECT_PATH)).to be_empty
        end

        context "given an object with addressing" do
          before_each { object.to = object.cc = [] of String }

          context "when it is addressed to a specific actor" do
            before_each { object.to = ["http://example.com/actor"] }

            it "renders the direct checkbox as checked" do
              expect(subject.xpath_nodes(DIRECT_PATH)).not_to be_empty
            end
          end

          context "when it is addressed to the author's followers" do
            before_each { object.cc = [object.attributed_to.followers.not_nil!] }

            it "renders the private checkbox as checked" do
              expect(subject.xpath_nodes(PRIVATE_PATH)).not_to be_empty
            end
          end
        end
      end

      context "when default editor is text/html" do
        before_each { Global.account.not_nil!.assign(default_editor: "text/html; editor=trix") }

        it "renders the trix editor" do
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end

        it "sets media-type to text/html" do
          expect(subject.xpath_nodes("//input[@name='media-type']/@value").first).to eq("text/html; editor=trix")
        end

        context "but object is text/markdown" do
          before_each do
            object.source = ActivityPub::Object::Source.new("# Test", "text/markdown")
          end

          it "renders the markdown editor" do
            expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).not_to be_empty
          end

          it "sets media-type to text/markdown" do
            expect(subject.xpath_nodes("//input[@name='media-type']/@value").first).to eq("text/markdown")
          end
        end
      end

      context "when default editor is text/markdown" do
        before_each { Global.account.not_nil!.assign(default_editor: "text/markdown") }

        it "renders the markdown editor" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).not_to be_empty
        end

        it "sets media-type to text/markdown" do
          expect(subject.xpath_nodes("//input[@name='media-type']/@value").first).to eq("text/markdown")
        end

        context "but object is text/html" do
          before_each do
            object.source = ActivityPub::Object::Source.new("<p>Test</p>", "text/html; editor=trix")
          end

          it "renders the trix editor" do
            expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
          end

          it "sets media-type to text/html" do
            expect(subject.xpath_nodes("//input[@name='media-type']/@value").first).to eq("text/html; editor=trix")
          end
        end
      end

      context "when object has no source" do
        before_each do
          Global.account.not_nil!.assign(default_editor: "text/markdown")
          object.assign(source: nil).save
        end

        pre_condition { expect(object.new_record?).to be_false }

        it "renders trix editor regardless of account default" do
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end
      end

      context "when object is new" do
        before_each do
          Global.account.not_nil!.assign(default_editor: "text/markdown")
          object.assign(source: nil)
        end

        pre_condition { expect(object.new_record?).to be_true }

        it "uses account default" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).not_to be_empty
        end
      end

      context "an object with errors" do
        before_each { object.errors["object"] = ["has errors"] }

        it "renders the error class" do
          expect(subject.xpath_nodes("//form/@class").first).to match(/\berror\b/)
        end
      end

      context "with editor=markdown" do
        let(env) { make_env("GET", "/editor?editor=markdown") }

        it "renders markdown editor" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).not_to be_empty
          expect(subject.xpath_nodes("//trix-editor")).to be_empty
        end

        it "includes hidden input" do
          expect(subject.xpath_nodes("//input[@type='hidden'][@name='editor'][@value='markdown']")).not_to be_empty
        end
      end

      context "with editor=rich-text" do
        let(env) { make_env("GET", "/editor?editor=rich-text") }

        it "renders rich-text editor" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).to be_empty
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end

        it "includes hidden input" do
          expect(subject.xpath_nodes("//input[@type='hidden'][@name='editor'][@value='rich-text']")).not_to be_empty
        end
      end

      context "with invalid editor parameter" do
        let(env) { make_env("GET", "/editor?editor=invalid") }

        it "falls back to default editor" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).to be_empty
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end
      end

      context "with duplicate editor parameters" do
        let(env) { make_env("GET", "/editor?editor=markdown&editor=markdown") }

        it "includes only one hidden input" do
          expect(subject.xpath_nodes("//input[@type='hidden'][@name='editor'][@value='markdown']").size).to eq(1)
        end
      end

      context "with unsupported editor" do
        let_build(note, named: object, local: true)
        let(env) { make_env("GET", "/editor?editor=poll") }

        it "shows warning" do
          expect(subject.xpath_nodes("//div[contains(@class,'warning')]//li"))
            .to contain_exactly(/not supported.*poll/)
        end
      end

      context "with mutually exclusive editors" do
        let(env) { make_env("GET", "/editor?editor=markdown&editor=rich-text") }

        it "shows warning" do
          expect(subject.xpath_nodes("//div[contains(@class,'warning')]//li"))
            .to contain_exactly(/mutually exclusive/)
        end
      end

      context "with editor=markdown in body" do
        let(env) { make_env("POST", "/editor", "editor=markdown") }

        it "renders markdown editor" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).not_to be_empty
          expect(subject.xpath_nodes("//trix-editor")).to be_empty
        end
      end

      context "with editor=rich-text in body" do
        let(env) { make_env("POST", "/editor", "editor=rich-text") }

        it "renders rich-text editor" do
          expect(subject.xpath_nodes("//textarea[@class='markdown-editor']")).to be_empty
          expect(subject.xpath_nodes("//trix-editor")).not_to be_empty
        end
      end
    end
  end

  describe "editor.json.ecr" do
    let(env) { make_env("GET", "/editor") }

    subject do
      JSON.parse(render "./src/views/partials/editor.json.ecr")
    end

    let_build(:object, local: true)

    context "if authenticated" do
      let(account) { register }

      sign_in(as: account.username)

      context "given a new object" do
        pre_condition { expect(object.new_record?).to be_true }

        it "does not render the object's iri" do
          expect(subject["object"]?).to be_nil
        end

        it "uses the default language" do
          expect(subject["language"]).to eq("en")
        end

        context "if no default language is set" do
          before_each { Global.account.not_nil!.language = nil }

          it "does not render a key for language" do
            expect(subject.as_h.has_key?("language")).to be_false
          end
        end

        context "given an assigned language" do
          before_each { object.assign(language: "fr") }

          it "uses the assigned language" do
            expect(subject["language"]).to eq("fr")
          end
        end

        it "does not render the media-type" do
          expect(subject.as_h.has_key?("media-type")).to be_false
        end

        context "given an assigned media_type" do
          before_each { object.assign(media_type: "text/markdown") }

          it "renders the assigned media-type" do
            expect(subject["media-type"]).to eq("text/markdown")
          end
        end
      end

      context "given a saved object" do
        before_each { object.save }

        pre_condition { expect(object.new_record?).to be_false }

        it "renders the object's iri" do
          expect(subject["object"]?).to eq(object.iri)
        end
      end

      context "given a reply" do
        let_build(:object, named: :original)

        before_each { object.assign(in_reply_to: original).save }

        it "renders the replies to object's iri" do
          expect(subject["in-reply-to"]?).to eq(original.iri)
        end
      end

      context "visibility" do
        it "renders public visibility" do
          expect(subject["visibility"]).to eq("public")
        end

        context "given an object with addressing" do
          before_each { object.to = object.cc = [] of String }

          context "when it is addressed to a specific actor" do
            before_each { object.to = ["http://example.com/actor"] }

            it "renders direct visibility" do
              expect(subject["visibility"]).to eq("direct")
            end
          end

          context "when it is addressed to the author's followers" do
            before_each { object.cc = [object.attributed_to.followers.not_nil!] }

            it "renders private visibility" do
              expect(subject["visibility"]).to eq("private")
            end
          end
        end
      end

      context "an object with errors" do
        before_each { object.errors["object"] = ["has errors"] }

        it "renders the errors" do
          expect(subject["errors"]["object"]).to eq(["has errors"])
        end
      end
    end
  end
end
