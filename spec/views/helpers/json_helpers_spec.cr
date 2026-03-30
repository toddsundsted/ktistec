require "./support_spec"

Spectator.describe "helpers" do
  setup_spec

  include Ktistec::ViewHelper

  let(model) { ViewHelperSpecSupport::Model.new }

  let(collection) { Ktistec::Util::PaginatedArray(ViewHelperSpecSupport::Model).new }

  describe "activity_pub_collection" do
    let(query) { "" }

    let(env) { make_env("GET", "/#{query}") }

    let(host) { Ktistec.settings.host }

    subject do
      JSON.parse(String.build { |content_io| activity_pub_collection(collection) }) # ameba:disable Lint/UnusedArgument
    end

    it "generates a JSON-LD document" do
      expect(subject["@context"]).to eq("https://www.w3.org/ns/activitystreams")
    end

    it "is an ordered collection" do
      expect(subject["type"]).to eq("OrderedCollection")
    end

    it "nests the first page of items" do
      expect(subject["first"]["id"]).to eq("https://test.test/?page=1")
    end

    context "the first page of items" do
      subject { super["first"] }

      it "is an ordered collection page" do
        expect(subject["type"]).to eq("OrderedCollectionPage")
      end

      it "includes an ordered collection of items" do
        expect(subject["orderedItems"]).to be_truthy
      end

      it "does not include a link to the next page" do
        expect(subject["next"]?).to be_nil
      end

      context "with more pages" do
        before_each { collection.more = true }

        it "includes a link to the next page" do
          expect(subject["next"]?).to eq("https://test.test/?page=2")
        end
      end
    end

    context "the second page of items" do
      let(query) { "?page=2" }

      it "is an ordered collection page" do
        expect(subject["type"]).to eq("OrderedCollectionPage")
      end

      it "includes an ordered collection of items" do
        expect(subject["orderedItems"]?).to be_truthy
      end

      it "includes a link to the previous page" do
        expect(subject["prev"]?).to eq("https://test.test/?page=1")
      end

      it "does not include a link to the previous page" do
        expect(subject["next"]?).to be_nil
      end

      context "with more pages" do
        before_each { collection.more = true }

        it "includes a link to the next page" do
          expect(subject["next"]?).to eq("https://test.test/?page=3")
        end
      end
    end
  end

  describe "activity_pub_collection" do
    let(query) { "" }

    let(env) { make_env("GET", "/#{query}") }

    let(host) { Ktistec.settings.host }

    let(collection) do
      super.tap do |c|
        c.cursor_start = 100_i64
        c.cursor_end = 50_i64
      end
    end

    subject do
      JSON.parse(String.build { |content_io| activity_pub_collection(collection) }) # ameba:disable Lint/UnusedArgument
    end

    it "generates a JSON-LD document" do
      expect(subject["@context"]).to eq("https://www.w3.org/ns/activitystreams")
    end

    it "is an ordered collection" do
      expect(subject["type"]).to eq("OrderedCollection")
    end

    it "nests the first page of items" do
      expect(subject["first"]["id"]).to eq("https://test.test/")
    end

    context "the first page of items" do
      subject { super["first"] }

      it "is an ordered collection page" do
        expect(subject["type"]).to eq("OrderedCollectionPage")
      end

      it "includes an ordered collection of items" do
        expect(subject["orderedItems"]).to be_truthy
      end

      it "does not include a link to the next page" do
        expect(subject["next"]?).to be_nil
      end

      context "with more pages" do
        before_each { collection.more = true }

        it "includes a link to the next page" do
          expect(subject["next"]?).to eq("https://test.test/?max_id=50")
        end
      end
    end

    context "on a page of items" do
      let(query) { "?max_id=100" }

      it "is an ordered collection page" do
        expect(subject["type"]).to eq("OrderedCollectionPage")
      end

      it "includes an ordered collection of items" do
        expect(subject["orderedItems"]?).to be_truthy
      end

      it "includes a link to the previous page" do
        expect(subject["prev"]?).to eq("https://test.test/?min_id=100")
      end

      it "does not include a link to the next page" do
        expect(subject["next"]?).to be_nil
      end

      context "with more pages" do
        before_each { collection.more = true }

        it "includes a link to the next page" do
          expect(subject["next"]?).to eq("https://test.test/?max_id=50")
        end
      end
    end
  end

  describe "error_block" do
    subject do
      error_block(model, false)
    end

    it "emits a block of errors" do
      expect(subject).to eq(%q|"errors":{"field":["is wrong"]}|)
    end
  end

  describe "field_pair" do
    subject do
      field_pair(model, field, false)
    end

    it "emits a key/value pair" do
      expect(subject).to eq(%q|"field":"Value"|)
    end
  end
end
