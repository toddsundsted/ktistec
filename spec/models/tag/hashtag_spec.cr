require "../../../src/models/tag/hashtag"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class Tag
  class_property hashtag_recount_count : Int64 = 0

  private def recount
    Tag.hashtag_recount_count += 1
    previous_def
  end
end

Spectator.describe Tag::Hashtag do
  setup_spec

  context "validation" do
    it "rejects missing subject" do
      new_tag = described_class.new(subject_iri: "missing", name: "missing")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject")
    end

    it "rejects blank name" do
      new_tag = described_class.new(name: "")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("name")
    end
  end

  describe "#save" do
    let_build(:object, local: true)

    it "strips the leading #" do
      new_tag = described_class.new(subject: object, name: "#foo")
      expect { new_tag.save }.to change { new_tag.name }.from("#foo").to("foo")
    end

    pre_condition { expect(object.draft?).to be_true }

    it "does not change the count" do
      new_tag = described_class.new(subject: object, name: "#foo")
      expect { new_tag.save }.not_to change { Tag.hashtag_recount_count }
    end
  end

  describe "#destroy" do
    let_create(:object, local: true)

    pre_condition { expect(object.draft?).to be_true }

    it "does not change the count" do
      new_tag = described_class.new(subject: object, name: "#foo")
      expect { new_tag.destroy }.not_to change { Tag.hashtag_recount_count }
    end
  end

  let!(author) { register.actor }

  macro create_tagged_object(index, *tags)
    let_create!(
      :object, named: object{{index}},
      attributed_to: author,
      published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
      local: true,
    )
    let_create!(
      :create, named: create{{index}},
      object: object{{index}},
      actor: author,
    )
    before_each do
      put_in_outbox(author, create{{index}})
      {% for tag in tags %}
        described_class.new(
          name: {{tag}},
          subject: object{{index}},
        ).save
      {% end %}
    end
  end

  describe ".most_recent_object" do
    create_tagged_object(1, "foo", "bar")
    create_tagged_object(2, "foo")
    create_tagged_object(3, "foo", "bar")
    create_tagged_object(4, "foo")
    create_tagged_object(5, "foo", "quux")

    it "returns the most recent object with the tag" do
      expect(described_class.most_recent_object("bar")).to eq(object3)
    end

    it "does not return draft objects" do
      object5.assign(published: nil).save
      expect(described_class.most_recent_object("foo")).to eq(object4)
    end

    it "does not return deleted objects" do
      object5.delete!
      expect(described_class.most_recent_object("foo")).to eq(object4)
    end

    it "does not return blocked objects" do
      object5.block!
      expect(described_class.most_recent_object("foo")).to eq(object4)
    end

    it "does not return objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.most_recent_object("foo")).to be_nil
    end

    it "does not return objects with blocked attributed to actors" do
      author.block!
      expect(described_class.most_recent_object("foo")).to be_nil
    end

    it "does not return objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.most_recent_object("foo")).to be_nil
    end
  end

  describe ".all_objects" do
    create_tagged_object(1, "foo", "bar")
    create_tagged_object(2, "foo")
    create_tagged_object(3, "foo", "bar")
    create_tagged_object(4, "foo")
    create_tagged_object(5, "foo", "quux")

    it "returns objects with the tag" do
      expect(described_class.all_objects("bar", limit: 5)).to eq([object3, object1])
    end

    it "filters out draft objects" do
      object5.assign(published: nil).save
      expect(described_class.all_objects("foo", limit: 5)).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete!
      expect(described_class.all_objects("foo", limit: 5)).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block!
      expect(described_class.all_objects("foo", limit: 5)).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.all_objects("foo", limit: 5)).to be_empty
    end

    it "filters out objects with blocked attributed to actors" do
      author.block!
      expect(described_class.all_objects("foo", limit: 5)).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.all_objects("foo", limit: 5)).to be_empty
    end

    it "limits the results" do
      expect(described_class.all_objects("foo", limit: 2)).to eq([object5, object4])
    end

    it "paginates with max_id" do
      expect(described_class.all_objects("foo", max_id: object5.id, limit: 2)).to eq([object4, object3])
    end

    it "paginates with min_id" do
      expect(described_class.all_objects("foo", min_id: object1.id, limit: 2)).to eq([object3, object2])
    end

    it "reports more results" do
      expect(described_class.all_objects("foo", limit: 2).has_next?).to be_true
    end

    it "reports no more results" do
      expect(described_class.all_objects("foo", limit: 5).has_next?).not_to be_true
    end

    it "returns the first page" do
      expect(described_class.all_objects("foo", max_id: 0_i64, limit: 2)).to eq([object5, object4])
    end

    context "given an object from another tag" do
      create_tagged_object(6, "other")

      it "returns the first page" do
        expect(described_class.all_objects("foo", max_id: object6.id, limit: 2)).to eq([object5, object4])
      end
    end
  end

  describe ".all_objects with since parameter" do
    create_tagged_object(1, "foo")
    create_tagged_object(2, "foo", "bar")
    create_tagged_object(3, "foo")

    let(since) { Time.utc(2016, 2, 15, 10, 30, 0) }

    before_each do
      described_class.where(name: "foo", subject_iri: object1.iri).first.assign(created_at: since - 1.5.hours).save
      described_class.where(name: "foo", subject_iri: object2.iri).first.assign(created_at: since + 30.minutes).save
      described_class.where(name: "bar", subject_iri: object2.iri).first.assign(created_at: since + 30.minutes).save
      described_class.where(name: "foo", subject_iri: object3.iri).first.assign(created_at: since + 1.5.hours).save
    end

    it "returns count of objects tagged since given time" do
      expect(described_class.all_objects("foo", since)).to eq(2)
    end

    it "returns count of objects tagged since given time" do
      expect(described_class.all_objects("bar", since)).to eq(1)
    end

    it "returns zero when no objects tagged since given time" do
      expect(described_class.all_objects("foo", since + 3.hours)).to eq(0)
    end

    it "returns zero for non-existent tag" do
      expect(described_class.all_objects("nonexistent", since - 3.hours)).to eq(0)
    end

    it "filters out draft objects" do
      object2.assign(published: nil).save
      expect(described_class.all_objects("foo", since)).to eq(1)
    end

    it "filters out deleted objects" do
      object2.delete!
      expect(described_class.all_objects("foo", since)).to eq(1)
    end

    it "filters out blocked objects" do
      object2.block!
      expect(described_class.all_objects("foo", since)).to eq(1)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.all_objects("foo", since)).to eq(0)
    end

    it "filters out objects with blocked attributed to actors" do
      author.block!
      expect(described_class.all_objects("foo", since)).to eq(0)
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.all_objects("foo", since)).to eq(0)
    end
  end

  describe ".all_objects_count" do
    create_tagged_object(1, "foo", "bar")
    create_tagged_object(2, "foo")
    create_tagged_object(3, "foo", "bar")
    create_tagged_object(4, "foo")
    create_tagged_object(5, "foo", "quux")

    it "returns count of objects with the tag" do
      expect(described_class.all_objects_count("bar")).to eq(2)
    end

    it "returns zero" do
      expect(described_class.all_objects_count("thud")).to eq(0)
    end
  end

  describe ".public_posts" do
    create_tagged_object(1, "foo", "bar")
    create_tagged_object(2, "foo")
    create_tagged_object(3, "foo", "bar")
    create_tagged_object(4, "foo")
    create_tagged_object(5, "foo", "quux")

    it "returns objects with the tag" do
      expect(described_class.public_posts("bar", limit: 5)).to eq([object3, object1])
    end

    it "filters out non-published objects" do
      object5.assign(published: nil).save
      expect(described_class.public_posts("foo", limit: 5)).not_to have(object5)
    end

    it "filters out non-visible objects" do
      object5.assign(visible: false).save
      expect(described_class.public_posts("foo", limit: 5)).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete!
      expect(described_class.public_posts("foo", limit: 5)).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block!
      expect(described_class.public_posts("foo", limit: 5)).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.public_posts("foo", limit: 5)).to be_empty
    end

    it "filters out objects with blocked attributed to actors" do
      author.block!
      expect(described_class.public_posts("foo", limit: 5)).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.public_posts("foo", limit: 5)).to be_empty
    end

    context "given a shared object" do
      let_create!(:object, named: shared, published: Time.utc(2016, 2, 15, 10, 20, 6))
      let_create!(:announce, object: shared, actor: author)
      before_each do
        put_in_outbox(author, announce)
        described_class.new(name: "foo", subject: shared).save
      end

      it "includes the shared object" do
        expect(described_class.public_posts("foo", limit: 6)).to have(shared)
      end
    end

    it "limits the results" do
      expect(described_class.public_posts("foo", limit: 2)).to eq([object5, object4])
    end

    it "paginates with max_id" do
      expect(described_class.public_posts("foo", max_id: object5.id, limit: 2)).to eq([object4, object3])
    end

    it "paginates with min_id" do
      expect(described_class.public_posts("foo", min_id: object1.id, limit: 2)).to eq([object3, object2])
    end

    it "reports more results" do
      expect(described_class.public_posts("foo", limit: 2).has_next?).to be_true
    end

    it "reports no more results" do
      expect(described_class.public_posts("foo", limit: 5).has_next?).not_to be_true
    end

    it "returns the first page" do
      expect(described_class.public_posts("foo", max_id: 0_i64, limit: 2)).to eq([object5, object4])
    end

    context "given multiple outbox items for the same object" do
      let_build(:create, named: extra_activity, actor: author, object: object3)
      let_create!(:outbox_relationship, owner: author, activity: extra_activity)

      it "emits the object once" do
        expect(described_class.public_posts("foo", limit: 10)).to eq([object3, object5, object4, object2, object1])
      end

      it "does not emit the object on the next page" do
        expect(described_class.public_posts("foo", max_id: object3.id, limit: 5)).to eq([object5, object4, object2, object1])
      end
    end

    context "given an object id from another tag" do
      create_tagged_object(6, "other")

      it "returns the first page" do
        expect(described_class.public_posts("foo", max_id: object6.id, limit: 2)).to eq([object5, object4])
      end
    end
  end

  describe ".public_posts_count" do
    create_tagged_object(1, "foo", "bar")
    create_tagged_object(2, "foo")
    create_tagged_object(3, "foo", "bar")
    create_tagged_object(4, "foo")
    create_tagged_object(5, "foo", "quux")

    it "returns count of objects with the tag" do
      expect(described_class.public_posts_count("bar")).to eq(2)
    end

    it "filters out non-published objects" do
      object5.assign(published: nil).save
      expect(described_class.public_posts_count("foo")).to eq(4)
    end

    it "filters out non-visible objects" do
      object5.assign(visible: false).save
      expect(described_class.public_posts_count("foo")).to eq(4)
    end

    it "filters out deleted objects" do
      object5.delete!
      expect(described_class.public_posts_count("foo")).to eq(4)
    end

    it "filters out blocked objects" do
      object5.block!
      expect(described_class.public_posts_count("foo")).to eq(4)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.public_posts_count("foo")).to eq(0)
    end

    it "filters out objects with blocked attributed to actors" do
      author.block!
      expect(described_class.public_posts_count("foo")).to eq(0)
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.public_posts_count("foo")).to eq(0)
    end

    context "given a shared object" do
      let_create!(:object, named: shared, published: Time.utc(2016, 2, 15, 10, 20, 6))
      let_create!(:announce, object: shared, actor: author)
      before_each do
        put_in_outbox(author, announce)
        described_class.new(name: "foo", subject: shared).save
      end

      it "includes the shared object" do
        expect(described_class.public_posts_count("foo")).to eq(6)
      end
    end
  end
end
