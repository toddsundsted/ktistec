require "../../src/models/activity_pub/activity/follow"

require "../spec_helper/controller"

Spectator.describe "partials" do
  setup_spec

  include Ktistec::Controller

  describe "collection.json.ecr" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/collection#{query}"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

    let(collection) do
      Ktistec::Util::PaginatedArray{
        ActivityPub::Object.new(iri: "foo"),
        ActivityPub::Object.new(iri: "bar")
      }
    end

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
    before_each do
      ActivityPub::Activity::Follow.new(
        iri: "#{{{from}}.origin}/activities/follow",
        actor: {{from}},
        object: {{to}}
      ).save
      {{from}}.follow(
        {{to}},
        confirmed: {{confirmed}},
        visible: true
      ).save
    end
  end

  describe "actor-large.html.slang" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/actor"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

    let(actor) do
      ActivityPub::Actor.new(
        iri: "https://remote/actors/foo_bar"
      ).save
    end

    subject do
      begin
        XML.parse_html(render "./src/views/partials/actor-large.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if anonymous" do
      it "does not render a form" do
        expect(subject.xpath_nodes("//form")).to be_empty
      end
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      context "if account actor is actor" do
        let(actor) { account.actor }

        it "does not render a form" do
          expect(subject.xpath_nodes("//form")).to be_empty
        end
      end

      context "if following actor" do
        follow(account.actor, actor)

        it "renders a button to unfollow" do
          expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Unfollow")
        end
      end

      it "renders a button to follow" do
        expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Follow")
      end
    end
  end

  describe "actor-small.html.slang" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/actors/foo_bar"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

    let(actor) do
      ActivityPub::Actor.new(
        iri: "https://remote/actors/foo_bar"
      ).save
    end

    subject do
      begin
        XML.parse_html(render "./src/views/partials/actor-small.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if anonymous" do
      it "does not render a form" do
        expect(subject.xpath_nodes("//form")).to be_empty
      end

      context "and actor is local" do
        before_each { actor.assign(iri: "https://test.test/actors/foo_bar").save }

        it "renders a link to remote follow" do
          expect(subject.xpath_string("string(//form//input[@type='submit']/@value)")).to eq("Follow")
        end
      end
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      context "if account actor is actor" do
        let(actor) { account.actor }

        it "does not render a form" do
          expect(subject.xpath_nodes("//form")).to be_empty
        end
      end

      # on a page of the actors the actor is following, the actor
      # expects to focus on actions regarding their decision to follow
      # those actors, so don't present accept/reject actions.

      context "and on a page of actors the actor is following" do
        let(env) do
          HTTP::Server::Context.new(
            HTTP::Request.new("GET", "/actors/foo_bar/following"),
            HTTP::Server::Response.new(IO::Memory.new)
          )
        end

        follow(actor, account.actor, confirmed: false)

        context "if already following" do
          follow(account.actor, actor)

          it "renders a button to unfollow" do
            expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Unfollow")
          end
        end

        it "renders a button to follow" do
          expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Follow")
        end
      end

      # otherwise...

      context "having not accepted or rejected a follow" do
        follow(actor, account.actor, confirmed: false)

        context "but already following" do
          follow(account.actor, actor)

          it "renders a button to accept" do
            expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).to have("Accept")
          end

          it "renders a button to reject" do
            expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).to have("Reject")
          end
        end

        it "renders a button to accept" do
          expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).to have("Accept")
        end

        it "renders a button to reject" do
          expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).to have("Reject")
        end
      end

      context "having accepted or rejected a follow" do
        follow(actor, account.actor, confirmed: true)

        context "and already following" do
          follow(account.actor, actor)

          it "renders a button to unfollow" do
            expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Unfollow")
          end
        end

        it "renders a button to follow" do
          expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Follow")
        end
      end

      context "when already following" do
        follow(account.actor, actor)

        it "renders a button to unfollow" do
          expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Unfollow")
        end
      end

      it "renders a button to follow" do
        expect(subject.xpath_string("string(//form//button[@type='submit']/text())")).to eq("Follow")
      end
    end
  end

  describe "object.html.slang" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/object"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

    subject do
      begin
        XML.parse_html(render "./src/views/partials/object.html.slang")
      rescue XML::Error
        XML.parse_html("<div/>").document
      end
    end

    context "if authenticated" do
      let(account) { register }

      before_each { env.account = account }

      context "and a draft" do
        let(_author) { account.actor }
        let(_actor) { account.actor }
        let(_object) do
          ActivityPub::Object.new(
            iri: "https://test.test/objects/object"
          ).save
        end

        pre_condition { expect(_object.draft?).to be_true }

        it "does not render a button to reply" do
          expect(subject.xpath_nodes("//a/button/text()").map(&.text)).not_to have("Reply")
        end

        it "does not render a button to like" do
          expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).not_to have("Like")
        end

        it "does not render a button to share" do
          expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).not_to have("Share")
        end

        it "renders a button to delete" do
          expect(subject.xpath_nodes("//form//button[@type='submit']/text()").map(&.text)).to have("Delete")
        end

        it "renders a button to edit" do
          expect(subject.xpath_nodes("//a/button/text()").map(&.text)).to have("Edit")
        end
      end
    end
  end
end
