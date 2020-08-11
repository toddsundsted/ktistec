require "../spec_helper"

Spectator.describe "partials" do
  include Balloon::Controller

  describe "collection.json.ecr" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/collection#{query}"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

    let(collection) do
      Balloon::Util::PaginatedArray{
        ActivityPub::Object.new(iri: "foo"),
        ActivityPub::Object.new(iri: "bar")
      }
    end

    subject { JSON.parse(render "./src/views/partials/collection.json.ecr") }

    context "when paginated" do
      let(query) { "?page=0&size=2" }

      it "renders a collection page" do
        expect(subject.dig("type")).to eq("OrderedCollectionPage")
      end

      it "contains the id of the collection page" do
        expect(subject.dig("id")).to eq("#{Balloon.host}/collection?page=0&size=2")
      end

      it "contains a page of items" do
        expect(subject.dig("orderedItems").as_a).to contain_exactly("foo", "bar")
      end

      it "does not contain navigation links" do
        expect(subject.dig?("prev")).to be_nil
        expect(subject.dig?("next")).to be_nil
      end

      context "and on the second page" do
        let(query) { "?page=1&size=2" }

        it "contains a link to the previous page" do
          expect(subject.dig?("prev")).to eq("#{Balloon.host}/collection?page=0&size=2")
        end
      end

      context "and contains more" do
        before_each { collection.more = true }

        it "contains a link to the next page" do
          expect(subject.dig?("next")).to eq("#{Balloon.host}/collection?page=1&size=2")
        end
      end
    end

    context "when not paginated" do
      let(query) { "" }

      it "renders a collection" do
        expect(subject.dig("type")).to eq("OrderedCollection")
      end

      it "contains the id of the collection" do
        expect(subject.dig("id")).to eq("#{Balloon.host}/collection")
      end

      it "does not contain any items" do
        expect(subject.dig?("orderedItems")).to be_nil
      end

      it "contains the first collection page" do
        expect(subject.dig("first", "type")).to eq("OrderedCollectionPage")
      end

      it "contains the first collection page" do
        expect(subject.dig("first", "id")).to eq("#{Balloon.host}/collection?page=0")
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
          expect(subject.dig?("first", "next")).to eq("#{Balloon.host}/collection?page=1")
        end
      end
    end
  end
end
