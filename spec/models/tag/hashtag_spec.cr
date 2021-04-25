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

  describe ".objects_with_tag" do
    let(author) { ActivityPub::Actor.new(iri: "https://test.test/actors/author") }

    macro create_tagged_object(index, *tags)
      let!(object{{index}}) do
        ActivityPub::Object.new(
          iri: "https://test.test/objects/object{{index}}",
          attributed_to: author,
          published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
          visible: true
        ).save
      end
      before_each do
        {% for tag in tags %}
          described_class.new(
            name: {{tag}},
            subject: object{{index}}
          ).save
        {% end %}
      end
    end

    create_tagged_object(1, "foo", "bar")
    create_tagged_object(2, "foo")
    create_tagged_object(3, "foo", "bar")
    create_tagged_object(4, "foo")
    create_tagged_object(5, "foo", "quux")

    it "returns objects with the tag" do
      expect(described_class.objects_with_tag("bar")).to eq([object3, object1])
    end

    it "filters out non-published objects" do
      object5.assign(published: nil).save
      expect(described_class.objects_with_tag("foo")).not_to have(object5)
    end

    it "filters out non-visible objects" do
      object5.assign(visible: false).save
      expect(described_class.objects_with_tag("foo")).not_to have(object5)
    end

    it "filters out deleted objects" do
      ActivityPub::Object.find(object5.id).delete
      expect(described_class.objects_with_tag("foo")).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete
      expect(described_class.objects_with_tag("foo")).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.objects_with_tag("foo")).to be_empty
    end

    it "paginates the results" do
      expect(described_class.objects_with_tag("foo", 1, 2)).to eq([object5, object4])
      expect(described_class.objects_with_tag("foo", 2, 2)).to eq([object3, object2])
      expect(described_class.objects_with_tag("foo", 2, 2).more?).to be_true
    end
  end
end
