require "../../../src/models/tag/hashtag"

require "../../spec_helper/model"

Spectator.describe Tag::Hashtag do
  setup_spec

  context "creation" do
    let(actor) { ActivityPub::Actor.new(iri: "https://test.test/actors/foorbar") }
    let(object) { ActivityPub::Object.new(iri: "https://test.test/objects/foorbar") }

    it "associates with an actor" do
      expect{described_class.new(subject: actor, name: "actor").save}.to change{Tag::Hashtag.count}.by(1)
      expect(described_class.find(name: "actor").subject).to eq(actor)
    end

    it "associates with an object" do
      expect{described_class.new(subject: object, name: "object").save}.to change{Tag::Hashtag.count}.by(1)
      expect(described_class.find(name: "object").subject).to eq(object)
    end
  end

  context "validation" do
    it "rejects missing subject" do
      new_tag = described_class.new(subject_iri: "missing", name: "missing")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject")
    end
  end
end
