require "../../src/services/object_factory"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe ObjectFactory do
  setup_spec

  let_create(:actor, local: true)

  describe ".build_from_params" do
    let(params) do
      {
        "content" => "Data content",
        "visibility" => "public"
      }
    end

    it "creates a new object" do
      result = ObjectFactory.build_from_params(params, actor)
      expect(result.valid?).to be_true
      expect(result.object).to be_a(ActivityPub::Object::Note)
      expect(result.object.content).to eq("Data content")
    end

    context "given existing object" do
      let_create(:note, attributed_to: actor, local: true)

      let(params) do
        {
          "content" => "Updated content",
          "visibility" => "public"
        }
      end

      it "updates an existing object" do
        result = ObjectFactory.build_from_params(params, actor, note)
        expect(result.valid?).to be_true
        expect(result.object).to eq(note)
        expect(result.object.content).to eq("Updated content")
      end
    end
  end
end
