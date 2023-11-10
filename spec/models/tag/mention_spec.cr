require "../../../src/models/tag/mention"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Tag::Mention do
  setup_spec

  context "validation" do
    it "rejects missing subject" do
      new_tag = described_class.new(subject_iri: "missing", name: "missing")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject")
    end
  end

  let_build(:actor, named: :author)

  macro create_object_with_mentions(index, *mentions)
    let_create!(
      :object, named: object{{index}},
      attributed_to: author,
      published: Time.utc(2016, 2, 15, 10, 20, {{index}})
    )
    before_each do
      {% for mention in mentions %}
        described_class.new(
        name: {{mention}},
        subject: object{{index}}
      ).save
      {% end %}
    end
  end

  describe ".all_objects" do
    create_object_with_mentions(1, "foo@remote", "bar@remote")
    create_object_with_mentions(2, "foo@remote")
    create_object_with_mentions(3, "foo@remote", "bar@remote")
    create_object_with_mentions(4, "foo@remote")
    create_object_with_mentions(5, "foo@remote", "quux@remote")

    it "returns objects with the mention" do
      expect(described_class.all_objects("bar@remote")).to eq([object3, object1])
    end

    it "filters out draft objects" do
      object5.assign(published: nil).save
      expect(described_class.all_objects("foo@remote")).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete
      expect(described_class.all_objects("foo@remote")).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block
      expect(described_class.all_objects("foo@remote")).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete
      expect(described_class.all_objects("foo@remote")).to be_empty
    end

    it "filters out objects with blocked attributed to actors" do
      author.block
      expect(described_class.all_objects("foo@remote")).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.all_objects("foo@remote")).to be_empty
    end

    it "paginates the results" do
      expect(described_class.all_objects("foo@remote", 1, 2)).to eq([object5, object4])
      expect(described_class.all_objects("foo@remote", 2, 2)).to eq([object3, object2])
      expect(described_class.all_objects("foo@remote", 2, 2).more?).to be_true
    end
  end

  describe ".count_objects" do
    create_object_with_mentions(1, "foo@remote", "bar@remote")
    create_object_with_mentions(2, "foo@remote")
    create_object_with_mentions(3, "foo@remote", "bar@remote")
    create_object_with_mentions(4, "foo@remote")
    create_object_with_mentions(5, "foo@remote", "quux@remote")

    it "returns count of objects with the mention" do
      expect(described_class.count_objects("bar@remote")).to eq(2)
    end

    it "filters out draft objects" do
      object5.assign(published: nil).save
      expect(described_class.count_objects("foo@remote")).to eq(4)
    end

    it "filters out deleted objects" do
      object5.delete
      expect(described_class.count_objects("foo@remote")).to eq(4)
    end

    it "filters out blocked objects" do
      object5.block
      expect(described_class.count_objects("foo@remote")).to eq(4)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete
      expect(described_class.count_objects("foo@remote")).to eq(0)
    end

    it "filters out objects with blocked attributed to actors" do
      author.block
      expect(described_class.count_objects("foo@remote")).to eq(0)
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.count_objects("foo@remote")).to eq(0)
    end
  end
end
