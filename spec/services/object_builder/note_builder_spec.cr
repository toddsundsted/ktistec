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
  end
end
