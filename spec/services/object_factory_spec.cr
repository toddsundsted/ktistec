require "../../src/services/object_factory"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe ObjectFactory do
  setup_spec

  let_create(:actor, local: true)

  describe ".build_from_params" do
    let(params) do
      {
        "content" => "New content",
        "visibility" => "public"
      }
    end

    it "creates a new Note object" do
      result = ObjectFactory.build_from_params(params, actor)
      expect(result.object).to be_a(ActivityPub::Object::Note)
      expect(result.object.new_record?).to be_true
      expect(result.object.content).to eq("New content")
    end

    context "given existing object" do
      let_create(:note, attributed_to: actor, local: true)

      let(params) do
        {
          "content" => "Updated content",
          "visibility" => "public"
        }
      end

      it "updates an existing Note object" do
        result = ObjectFactory.build_from_params(params, actor, note)
        expect(result.object).to eq(note)
        expect(result.object.new_record?).to be_false
        expect(result.object.content).to eq("Updated content")
      end
    end

    context "when poll-options is present" do
      let(params) do
        {
          "content" => "What is your favorite color?",
          "poll-options" => ["Red", "Blue", "Green"],
          "visibility" => "public"
        }
      end

      it "creates a new Question object" do
        result = ObjectFactory.build_from_params(params, actor)
        expect(result.object).to be_a(ActivityPub::Object::Question)
        expect(result.object.new_record?).to be_true
        expect(result.object.content).to eq("What is your favorite color?")
      end

      it "creates a new Poll object" do
        result = ObjectFactory.build_from_params(params, actor)
        object = result.object.as(ActivityPub::Object::Question)
        expect(object.poll.new_record?).to be_true
        expect(object.poll).to be_a(Poll)
      end
    end
  end
end
