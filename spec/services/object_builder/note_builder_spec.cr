require "../../../src/services/object_builder/note_builder"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe ObjectBuilder::NoteBuilder do
  setup_spec

  subject { described_class.new }

  let_create!(:actor, local: true)

  describe "#build" do
    let(params) do
      {
        "name"       => "Note title",
        "summary"    => "Content warning",
        "content"    => "Content",
        "media-type" => "text/plain",
        "sensitive"  => "true",
        "language"   => "en",
        "visibility" => "public",
      }
    end

    it "creates a Note" do
      result = subject.build(params, actor)
      expect(result.valid?).to be_true
      expect(result.object).to be_a(ActivityPub::Object::Note)
    end

    it "assigns unique IRI" do
      result = subject.build(params, actor)
      expect(result.object.iri).to match(/^https:\/\/test\.test\/objects\/[a-zA-Z0-9_-]+/)
    end

    context "given a draft note" do
      let_build(:note, attributed_to: actor, local: true)

      let(params) { {"content" => "Updated content"} }

      it "updates the draft note" do
        expect { subject.build(params, actor, note) }.to change { note.source.try(&.content) }.to("Updated content")
      end

      it "does not change IRI" do
        expect { subject.build(params, actor, note) }.not_to change { note.iri }
      end
    end

    context "given a published note" do
      let_create(:note, attributed_to: actor, local: true)

      let(params) { {"content" => "Updated content"} }

      it "updates the published note" do
        expect { subject.build(params, actor, note) }.to change { note.source.try(&.content) }.to("Updated content")
      end

      it "does not change IRI" do
        expect { subject.build(params, actor, note) }.not_to change { note.iri }
      end
    end

    context "given a quote parameter" do
      let_create(:object)

      context "when the quoted object exists" do
        let(params) { {"content" => "Quoting this", "quote" => object.iri} }

        it "sets quote_iri on the note" do
          result = subject.build(params, actor)
          expect(result.object.quote_iri).to eq(object.iri)
        end

        it "is valid" do
          result = subject.build(params, actor)
          expect(result.valid?).to be_true
        end
      end

      context "when the quoted object does not exist" do
        let(params) { {"content" => "Quoting this", "quote" => "https://remote/objects/missing"} }

        it "adds an error for quote" do
          result = subject.build(params, actor)
          expect(result.errors["quote"]).to contain("object not found")
        end

        it "is not valid" do
          result = subject.build(params, actor)
          expect(result.valid?).to be_false
        end
      end

      context "when the quote parameter is absent" do
        let(params) { {"content" => "No quote"} }

        it "does not set quote_iri" do
          result = subject.build(params, actor)
          expect(result.object.quote_iri).to be_nil
        end

        it "is valid" do
          result = subject.build(params, actor)
          expect(result.valid?).to be_true
        end
      end
    end
  end
end
