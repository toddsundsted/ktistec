require "../../../src/models/tag/label"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Tag::Label do
  setup_spec

  let_create(:actor, named: :owner, local: true)
  let_create(:object)

  context "validation" do
    it "rejects missing subject" do
      new_tag = described_class.new(owner: owner, subject_iri: "https://test.test/missing", name: "foo")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject")
    end

    it "rejects missing owner" do
      new_tag = described_class.new(href: "https://test.test/missing", subject: object, name: "foo")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("owner")
    end

    it "rejects blank name" do
      new_tag = described_class.new(owner: owner, subject: object, name: "")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("name")
    end

    context "given an existing label" do
      let_create!(:label, owner: owner, subject: object, name: "foo")

      it "rejects a duplicate" do
        new_tag = described_class.new(owner: owner, subject: object, name: "foo")
        expect(new_tag.valid?).to be_false
        expect(new_tag.errors.keys).to contain("name")
      end

      it "rejects a duplicate that includes a leading §" do
        new_tag = described_class.new(owner: owner, subject: object, name: "§foo")
        expect(new_tag.valid?).to be_false
        expect(new_tag.errors.keys).to contain("name")
      end

      it "remains valid" do
        expect(label.valid?).to be_true
      end

      context "and another owner" do
        let_create(:actor, named: :another, local: true)

        it "accepts the same name" do
          new_tag = described_class.new(owner: another, subject: object, name: "foo")
          expect(new_tag.valid?).to be_true
        end
      end

      context "and another subject" do
        let_create(:object, named: :another)

        it "accepts the same name" do
          new_tag = described_class.new(owner: owner, subject: another, name: "foo")
          expect(new_tag.valid?).to be_true
        end
      end
    end
  end

  describe "#save" do
    it "strips the leading §" do
      new_tag = described_class.new(owner: owner, subject: object, name: "§foo")
      expect { new_tag.save }.to change { new_tag.name }.from("§foo").to("foo")
    end

    it "leaves tag statistics unchanged" do
      new_tag = described_class.new(owner: owner, subject: object, name: "foo")
      expect { new_tag.save }.not_to change { Ktistec.database.scalar("SELECT count(*) FROM tag_statistics").as(Int64) }
    end
  end

  describe "#destroy" do
    let_create!(:label, owner: owner, subject: object, name: "foo")

    it "leaves tag statistics unchanged" do
      expect { label.destroy }.not_to change { Ktistec.database.scalar("SELECT count(*) FROM tag_statistics").as(Int64) }
    end
  end

  let_create(:actor, named: :author)

  macro create_labeled_object(index, *names)
    let_create!(
      :object, named: object{{index}},
      attributed_to: author,
      published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
    )
    before_each do
      {% for name in names %}
        described_class.new(owner: owner, subject: object{{index}}, name: {{name}}).save
      {% end %}
    end
  end

  describe ".all_objects" do
    create_labeled_object(1, "foo", "bar")
    create_labeled_object(2, "foo")
    create_labeled_object(3, "foo", "bar")
    create_labeled_object(4, "foo")
    create_labeled_object(5, "foo", "quux")

    it "returns objects with the label" do
      expect(described_class.all_objects(owner, "bar", limit: 5)).to eq([object3, object1])
    end

    it "matches the label regardless of case" do
      expect(described_class.all_objects(owner, "BAR", limit: 5)).to eq([object3, object1])
    end

    context "given a label added later to an older object" do
      before_each { described_class.new(owner: owner, subject: object2, name: "bar").save }

      it "returns the most recently labeled object first" do
        expect(described_class.all_objects(owner, "bar", limit: 5)).to eq([object2, object3, object1])
      end
    end

    context "given the same label by another owner" do
      let_create(:actor, named: :other)
      before_each { described_class.new(owner: other, subject: object2, name: "bar").save }

      it "does not return that owner's object" do
        expect(described_class.all_objects(owner, "bar", limit: 5)).to eq([object3, object1])
      end
    end

    it "filters out draft objects" do
      object5.assign(published: nil).save
      expect(described_class.all_objects(owner, "foo", limit: 5)).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete!
      expect(described_class.all_objects(owner, "foo", limit: 5)).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block!
      expect(described_class.all_objects(owner, "foo", limit: 5)).not_to have(object5)
    end

    it "filters out objects whose author is deleted" do
      author.delete!
      expect(described_class.all_objects(owner, "foo", limit: 5)).to be_empty
    end

    it "filters out objects whose author is blocked" do
      author.block!
      expect(described_class.all_objects(owner, "foo", limit: 5)).to be_empty
    end

    it "filters out objects whose author no longer exists" do
      author.destroy
      expect(described_class.all_objects(owner, "foo", limit: 5)).to be_empty
    end

    it "limits the results" do
      expect(described_class.all_objects(owner, "foo", limit: 2)).to eq([object5, object4])
    end

    it "returns the objects labeled before the max_id object" do
      expect(described_class.all_objects(owner, "foo", max_id: object5.id, limit: 5)).to eq([object4, object3, object2, object1])
    end

    it "returns the objects labeled after the min_id object" do
      expect(described_class.all_objects(owner, "foo", min_id: object1.id, limit: 5)).to eq([object5, object4, object3, object2])
    end
  end

  describe ".all_objects_count" do
    create_labeled_object(1, "foo", "bar")
    create_labeled_object(2, "foo")
    create_labeled_object(3, "foo", "bar")

    it "counts the objects with the label" do
      expect(described_class.all_objects_count(owner, "bar")).to eq(2)
    end

    it "does not count deleted objects" do
      object3.delete!
      expect(described_class.all_objects_count(owner, "bar")).to eq(1)
    end
  end

  describe ".names" do
    create_labeled_object(1, "foo", "bar")
    create_labeled_object(2, "foo")

    it "returns each of the owner's labels once" do
      expect(described_class.names(owner)).to eq(["bar", "foo"])
    end

    context "given a label by another owner" do
      let_create(:actor, named: :other)
      before_each { described_class.new(owner: other, subject: object2, name: "quux").save }

      it "does not return that owner's label" do
        expect(described_class.names(owner)).not_to contain("quux")
      end
    end

    it "does not return a label whose only object is deleted" do
      object1.delete!
      expect(described_class.names(owner)).to eq(["foo"])
    end
  end
end
