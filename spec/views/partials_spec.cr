require "../spec_helper"

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

  describe "follow.html.slang" do
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
        XML.parse(render "./src/views/partials/follow.html.slang")
      rescue XML::Error
        XML.parse("<div/>").document
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
        before_each do
          ActivityPub::Activity::Follow.new(
            iri: "https://test.test/activities/follow",
            actor: account.actor,
            object: actor
          ).save
          account.actor.follow(
            actor,
            confirmed: true,
            visible: true
          ).save
        end

        it "renders a button to unfollow" do
          expect(subject.xpath_string("string(//form//input[@type='submit']/@value)")).to eq("Unfollow")
        end
      end

      context "if not following actor" do
        it "renders a button to follow" do
          expect(subject.xpath_string("string(//form//input[@type='submit']/@value)")).to eq("Follow")
        end
      end
    end
  end
end
