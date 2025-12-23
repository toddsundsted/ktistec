require "../../../src/services/object_builders/object_builder"
require "../../../src/services/object_builders/build_result"
require "../../../src/models/activity_pub/object/note"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class TestObjectBuilder < ObjectBuilders::ObjectBuilder
  def build(params, actor, object = nil) : ObjectBuilders::BuildResult
    raise "Not implemented"
  end

  def calculate_addressing(params, actor, in_reply_to = nil)
    super
  end

  def apply_common_attributes(params, addressing, object, actor, in_reply_to = nil)
    super
  end

  def validate_reply_to(in_reply_to_iri, result)
    super
  end

  def collect_model_errors(object, result)
    super
  end
end

Spectator.describe ObjectBuilders::ObjectBuilder do
  setup_spec

  subject { TestObjectBuilder.new }

  let_create!(:actor, local: true)

  describe "#calculate_addressing" do
    context "with public visibility" do
      let(params) { {"visibility" => "public"} }

      it "sets visible to true" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:visible]).to be_true
      end

      it "includes Public in 'to'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:to]).to have("https://www.w3.org/ns/activitystreams#Public")
      end

      it "includes followers in 'cc'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:cc]).to have(actor.followers)
      end
    end

    context "with private visibility" do
      let(params) { {"visibility" => "private"} }

      it "sets visible to false" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:visible]).to be_false
      end

      it "does not include Public in 'to'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:to]).not_to have("https://www.w3.org/ns/activitystreams#Public")
      end

      it "includes followers in 'to'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:to]).to have(actor.followers)
      end
    end

    context "with direct visibility" do
      let(params) { {"visibility" => "direct"} }

      it "sets visible to false" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:visible]).to be_false
      end

      it "does not include Public in 'to'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:to]).not_to have("https://www.w3.org/ns/activitystreams#Public")
      end

      it "does not include followers in 'to'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:to]).not_to have(actor.followers)
      end
    end

    context "with additional 'to' recipients" do
      let(params) do
        {
          "visibility" => "public",
          "to" => "https://example.com/actor1,https://example.com/actor2",
        }
      end

      it "merges additional recipients into 'to'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:to]).to have("https://example.com/actor1")
        expect(result[:to]).to have("https://example.com/actor2")
      end
    end

    context "with additional 'cc' recipients" do
      let(params) do
        {
          "visibility" => "public",
          "cc" => "https://example.com/actor3,https://example.com/actor4",
        }
      end

      it "merges additional recipients into 'cc'" do
        result = subject.calculate_addressing(params, actor)
        expect(result[:cc]).to have("https://example.com/actor3")
        expect(result[:cc]).to have("https://example.com/actor4")
      end
    end

    context "with reply-to object" do
      let_create!(
        :actor, named: :other,
        local: true,
      )
      let_create!(
        :note, named: :parent,
        attributed_to: other,
        local: true,
        to: ["https://www.w3.org/ns/activitystreams#Public"],
        audience: ["https://example.com/group"],
      )

      let(params) { {"visibility" => "direct"} }

      it "adds parent's author to 'to'" do
        result = subject.calculate_addressing(params, actor, parent)
        expect(result[:to]).to have(other.iri)
      end

      it "inherits audience from parent" do
        result = subject.calculate_addressing(params, actor, parent)
        expect(result[:audience]).to eq(["https://example.com/group"])
      end
    end
  end

  describe "#apply_common_attributes" do
    let_build(:note, local: true)
    let(addressing) do
      {
        visible: true,
        to: Set{"https://www.w3.org/ns/activitystreams#Public"}.as(Set(String)),
        cc: Set{actor.followers.not_nil!}.as(Set(String)),
        audience: nil.as(Array(String)?),
      }
    end

    context "with all parameters" do
      let(params) do
        {
          "name" => "Note title",
          "summary" => "Content warning",
          "content" => "Note content",
          "media-type" => "text/plain",
          "sensitive" => "true",
          "language" => "en",
          "canonical-path" => "/custom/path",
        }
      end

      it "sets name" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.name).to eq("Note title")
      end

      it "sets summary" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.summary).to eq("Content warning")
      end

      it "sets source content" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.source.not_nil!.content).to eq("Note content")
      end

      it "sets source media_type" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.source.not_nil!.media_type).to eq("text/plain")
      end

      it "sets sensitive" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.sensitive).to be_true
      end

      it "sets language" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.language).to eq("en")
      end

      it "sets canonical_path" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.canonical_path).to eq("/custom/path")
      end

      it "sets attributed_to_iri" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.attributed_to_iri).to eq(actor.iri)
      end

      it "sets attributed_to" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.attributed_to).to eq(actor)
      end

      it "sets replies_iri" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.replies_iri).to eq("#{note.iri}/replies")
      end

      it "sets visible" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.visible).to be_true
      end

      it "sets to" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.to).to eq(["https://www.w3.org/ns/activitystreams#Public"])
      end

      it "sets cc" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.cc).to eq([actor.followers])
      end

      it "sets audience" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.audience).to be_nil
      end
    end

    context "with minimal parameters" do
      let(params) { {"content" => "Minimal"} }

      it "defaults media type" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.source.not_nil!.media_type).to eq("text/html; editor=trix")
      end

      it "defaults sensitive to false" do
        subject.apply_common_attributes(params, addressing, note, actor)
        expect(note.sensitive).to be_false
      end
    end

    context "as a reply" do
      let_create!(:actor, named: :other, local: true)
      let_create!(:note, named: :parent, attributed_to: other, local: true)
      let(params) { {"content" => "Reply"} }

      it "sets `in_reply_to`" do
        subject.apply_common_attributes(params, addressing, note, actor, parent)
        expect(note.in_reply_to).to eq(parent)
      end
    end
  end

  describe "#validate_reply_to" do
    let_build(:note, local: true)
    let(:result) { ObjectBuilders::BuildResult.new(note) }

    context "when in_reply_to_iri is nil" do
      it "returns nil" do
        expect(subject.validate_reply_to(nil, result)).to be_nil
      end

      it "does not add errors" do
        subject.validate_reply_to(nil, result)
        expect(result.valid?).to be_true
      end
    end

    context "when in_reply_to object exists" do
      let_create!(:note, named: :parent, local: true)

      it "returns the object" do
        found = subject.validate_reply_to(parent.iri, result)
        expect(found).to eq(parent)
      end

      it "does not add errors" do
        subject.validate_reply_to(parent.iri, result)
        expect(result.valid?).to be_true
      end
    end

    context "when in_reply_to object does not exist" do
      it "returns nil" do
        found = subject.validate_reply_to("https://test.test/objects/nonexistent", result)
        expect(found).to be_nil
      end

      it "adds error" do
        subject.validate_reply_to("https://test.test/objects/nonexistent", result)
        expect(result.valid?).to be_false
        expect(result.errors["in_reply_to"]).to have("object not found")
      end
    end
  end

  describe "#collect_model_errors" do
    let_build(:note, local: true)
    let(:result) { ObjectBuilders::BuildResult.new(note) }

    context "when object is valid" do
      it "does not add errors" do
        note.assign(
          source: ActivityPub::Object::Source.new("Valid content", "text/plain"),
          attributed_to: actor,
        )
        subject.collect_model_errors(note, result)
        expect(result.valid?).to be_true
      end
    end

    context "when object has validation errors" do
      it "adds model errors to result" do
        note.canonical_path = "invalid-no-slash"
        subject.collect_model_errors(note, result)
        expect(result.valid?).to be_false
        expect(result.errors).to have_key("canonical_path.from_iri")
        expect(result.errors["canonical_path.from_iri"]).to have("must be absolute")
      end
    end
  end
end
