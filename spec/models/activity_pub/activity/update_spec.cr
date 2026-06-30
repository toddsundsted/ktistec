require "../../../../src/models/activity_pub/activity/update"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::Update do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns an actor, object or one of their subclasses" do
      expect(typeof(subject.object)).to eq({{((ActivityPub::Actor.all_subclasses + ActivityPub::Object.all_subclasses) << ActivityPub::Actor << ActivityPub::Object).join("|").id}})
    end
  end

  context "validations" do
    context "when object is an object" do
      let_build(:actor, local: true)
      let_build(:object, attributed_to: actor)

      it "passes validation" do
        activity = subject.assign(actor: actor, object: object)
        expect(activity.valid_for_send?).to be_true
        expect(activity.errors["activity"]?).to be_nil
      end

      context "but the object is attributed to another actor" do
        let_build(:object)

        it "is invalid" do
          activity = subject.assign(actor: actor, object: object)
          expect(activity.valid_for_send?).to be_false
          expect(activity.errors["activity"]).to contain("object must be attributed to actor")
        end
      end
    end

    context "when object is an actor" do
      let_build(:actor, local: true)

      it "passes validation" do
        activity = subject.assign(actor: actor, object: actor)
        expect(activity.valid_for_send?).to be_true
        expect(activity.errors["activity"]?).to be_nil
      end

      context "but the actor is remote" do
        before_each { actor.assign(iri: "https://remote/actors/#{random_string}") }

        it "is invalid" do
          activity = subject.assign(actor: actor, object: actor)
          expect(activity.valid_for_send?).to be_false
          expect(activity.errors["activity"]).to contain("actor must be local")
        end
      end

      context "but the object is another actor" do
        let_build(:actor, named: :other, local: true)

        it "is invalid" do
          activity = subject.assign(actor: actor, object: other)
          expect(activity.valid_for_send?).to be_false
          expect(activity.errors["activity"]).to contain("object must be the actor")
        end
      end
    end
  end

  describe "#to_json_ld" do
    let_build(:actor, local: true)

    it "embeds the full actor document as the object" do
      activity = subject.assign(actor: actor, object: actor)
      object = JSON.parse(activity.to_json_ld(recursive: true))["object"]
      expect(object.as_h?).to be_truthy
      expect(object["preferredUsername"]?).to eq(actor.username)
    end
  end
end
