require "../../../src/models/tag/mention"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class Tag
  class_property mention_recount_count : Int64 = 0

  private def recount
    Tag.mention_recount_count += 1
    previous_def
  end
end

Spectator.describe Tag::Mention do
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

    it "strips the leading @" do
      new_tag = described_class.new(subject: object, name: "@foo@remote")
      expect { new_tag.save }.to change { new_tag.name }.from("@foo@remote").to("foo@remote")
    end

    it "adds the host if missing" do
      new_tag = described_class.new(subject: object, href: "http://example.com/foo", name: "foo")
      expect { new_tag.save }.to change { new_tag.name }.from("foo").to("foo@example.com")
    end

    it "does not change the host if present" do
      new_tag = described_class.new(subject: object, href: "http://example.com/foo", name: "foo@remote")
      expect { new_tag.save }.not_to change { new_tag.name }
    end

    pre_condition { expect(object.draft?).to be_true }

    it "does not change the count" do
      new_tag = described_class.new(subject: object, name: "@foo@remote")
      expect { new_tag.save }.not_to change { Tag.mention_recount_count }
    end
  end

  describe "#destroy" do
    let_create(:object, local: true)

    pre_condition { expect(object.draft?).to be_true }

    it "does not change the count" do
      new_tag = described_class.new(subject: object, name: "@foo@remote")
      expect { new_tag.destroy }.not_to change { Tag.mention_recount_count }
    end
  end

  let_build(:actor, named: :author)

  def mention_href(handle)
    user, _, host = handle.partition("@")
    "https://#{host}/users/#{user}"
  end

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
        href: mention_href({{mention}}),
        subject: object{{index}}
      ).save
      {% end %}
    end
  end

  describe ".most_recent_object" do
    create_object_with_mentions(1, "foo@remote", "bar@remote")
    create_object_with_mentions(2, "foo@remote")
    create_object_with_mentions(3, "foo@remote", "bar@remote")
    create_object_with_mentions(4, "foo@remote")
    create_object_with_mentions(5, "foo@remote", "quux@remote")

    it "returns the most recent object with the mention" do
      expect(described_class.most_recent_object(mention_href("bar@remote"))).to eq(object3)
    end

    it "does not return draft objects" do
      object5.assign(published: nil).save
      expect(described_class.most_recent_object(mention_href("foo@remote"))).to eq(object4)
    end

    it "does not return deleted objects" do
      object5.delete!
      expect(described_class.most_recent_object(mention_href("foo@remote"))).to eq(object4)
    end

    it "does not return blocked objects" do
      object5.block!
      expect(described_class.most_recent_object(mention_href("foo@remote"))).to eq(object4)
    end

    it "does not return objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.most_recent_object(mention_href("foo@remote"))).to be_nil
    end

    it "does not return objects with blocked attributed to actors" do
      author.block!
      expect(described_class.most_recent_object(mention_href("foo@remote"))).to be_nil
    end

    it "does not return objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.most_recent_object(mention_href("foo@remote"))).to be_nil
    end
  end

  describe ".all_objects" do
    create_object_with_mentions(1, "foo@remote", "bar@remote")
    create_object_with_mentions(2, "foo@remote")
    create_object_with_mentions(3, "foo@remote", "bar@remote")
    create_object_with_mentions(4, "foo@remote")
    create_object_with_mentions(5, "foo@remote", "quux@remote")

    it "returns objects with the mention" do
      expect(described_class.all_objects(mention_href("bar@remote"), limit: 5)).to eq([object3, object1])
    end

    it "filters out draft objects" do
      object5.assign(published: nil).save
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5)).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete!
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5)).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block!
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5)).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5)).to be_empty
    end

    it "filters out objects with blocked attributed to actors" do
      author.block!
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5)).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5)).to be_empty
    end

    it "limits the results" do
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 2)).to eq([object5, object4])
    end

    it "paginates with max_id" do
      expect(described_class.all_objects(mention_href("foo@remote"), max_id: object5.id, limit: 2)).to eq([object4, object3])
    end

    it "paginates with min_id" do
      expect(described_class.all_objects(mention_href("foo@remote"), min_id: object1.id, limit: 2)).to eq([object3, object2])
    end

    it "reports more results" do
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 2).has_next?).to be_true
    end

    it "reports no more results" do
      expect(described_class.all_objects(mention_href("foo@remote"), limit: 5).has_next?).not_to be_true
    end

    it "returns the first page" do
      expect(described_class.all_objects(mention_href("foo@remote"), max_id: 0_i64, limit: 2)).to eq([object5, object4])
    end

    context "given an object id from another mention" do
      create_object_with_mentions(6, "other@remote")

      it "returns the first page" do
        expect(described_class.all_objects(mention_href("foo@remote"), max_id: object6.id, limit: 2)).to eq([object5, object4])
      end
    end
  end

  describe ".all_objects with since parameter" do
    create_object_with_mentions(1, "foo@remote")
    create_object_with_mentions(2, "foo@remote", "bar@remote")
    create_object_with_mentions(3, "foo@remote")

    let(since) { Time.utc(2016, 2, 15, 10, 30, 0) }

    before_each do
      described_class.where(name: "foo@remote", subject_iri: object1.iri).first.assign(created_at: since - 1.5.hours).save
      described_class.where(name: "foo@remote", subject_iri: object2.iri).first.assign(created_at: since + 30.minutes).save
      described_class.where(name: "bar@remote", subject_iri: object2.iri).first.assign(created_at: since + 30.minutes).save
      described_class.where(name: "foo@remote", subject_iri: object3.iri).first.assign(created_at: since + 1.5.hours).save
    end

    it "returns count of objects mentioned since given time" do
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(2)
    end

    it "returns count of objects mentioned since given time" do
      expect(described_class.all_objects(mention_href("bar@remote"), since)).to eq(1)
    end

    it "returns zero when no objects mentioned since given time" do
      expect(described_class.all_objects(mention_href("foo@remote"), since + 3.hours)).to eq(0)
    end

    it "returns zero for non-existent mention" do
      expect(described_class.all_objects(mention_href("nonexistent@remote"), since - 3.hours)).to eq(0)
    end

    it "filters out draft objects" do
      object2.assign(published: nil).save
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(1)
    end

    it "filters out deleted objects" do
      object2.delete!
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(1)
    end

    it "filters out blocked objects" do
      object2.block!
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(1)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete!
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(0)
    end

    it "filters out objects with blocked attributed to actors" do
      author.block!
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(0)
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.all_objects(mention_href("foo@remote"), since)).to eq(0)
    end
  end

  describe ".all_objects_count" do
    create_object_with_mentions(1, "foo@remote", "bar@remote")
    create_object_with_mentions(2, "foo@remote")
    create_object_with_mentions(3, "foo@remote", "bar@remote")
    create_object_with_mentions(4, "foo@remote")
    create_object_with_mentions(5, "foo@remote", "quux@remote")

    it "returns count of objects with the mention" do
      expect(described_class.all_objects_count("bar@remote")).to eq(2)
    end

    it "returns zero" do
      expect(described_class.all_objects_count("thud")).to eq(0)
    end
  end

  describe ".dominant_href" do
    let_create(:object, named: object1, attributed_to: author)
    let_create(:object, named: object2, attributed_to: author)
    let_create(:object, named: object3, attributed_to: author)

    it "returns nil" do
      expect(described_class.dominant_href("foo@remote")).to be_nil
    end

    it "resolves a handle to its href" do
      described_class.new(name: "foo@remote", href: "https://remote/users/foo", subject: object1).save
      expect(described_class.dominant_href("foo@remote")).to eq("https://remote/users/foo")
    end

    it "ignores tags without an href" do
      described_class.new(name: "foo@remote", href: nil, subject: object1).save
      expect(described_class.dominant_href("foo@remote")).to be_nil
    end

    context "when a handle maps to more than one href" do
      before_each do
        described_class.new(name: "foo@remote", href: "https://remote/users/foo", subject: object1).save
        described_class.new(name: "foo@remote", href: "https://remote/users/foo", subject: object2).save
        described_class.new(name: "foo@remote", href: "https://remote/ap/foo", subject: object3).save
      end

      it "returns the dominant href" do
        expect(described_class.dominant_href("foo@remote")).to eq("https://remote/users/foo")
      end
    end

    context "when a handle maps to more than one href" do
      before_each do
        described_class.new(name: "foo@remote", href: "https://remote/users/foo", subject: object1).save
        described_class.new(name: "foo@remote", href: "https://remote/ap/foo", subject: object2).save
      end

      it "breaks the tie lexically on href" do
        expect(described_class.dominant_href("foo@remote")).to eq("https://remote/ap/foo")
      end
    end
  end

  describe ".dominant_name" do
    let_build(:object, named: object1)
    let_build(:object, named: object2)
    let_build(:object, named: object3)

    it "returns nil" do
      expect(described_class.dominant_name("https://remote/users/foo")).to be_nil
    end

    context "given a mention tag" do
      let_create!(:mention, name: "foo@remote", href: "https://remote/users/foo", subject: object1)

      it "resolves the href to its name" do
        expect(described_class.dominant_name("https://remote/users/foo")).to eq("foo@remote")
      end
    end

    context "when an href maps to more than one name" do
      let_create!(:mention, named: nil, name: "foo@remote", href: "https://remote/users/foo", subject: object1)
      let_create!(:mention, named: nil, name: "foo@remote", href: "https://remote/users/foo", subject: object2)
      let_create!(:mention, named: nil, name: "foo@other", href: "https://remote/users/foo", subject: object3)

      it "returns the dominant name" do
        expect(described_class.dominant_name("https://remote/users/foo")).to eq("foo@remote")
      end
    end

    context "when an href maps to more than one name" do
      let_create!(:mention, named: nil, name: "bbb@remote", href: "https://remote/users/foo", subject: object1)
      let_create!(:mention, named: nil, name: "aaa@remote", href: "https://remote/users/foo", subject: object2)

      it "breaks the tie lexically on name" do
        expect(described_class.dominant_name("https://remote/users/foo")).to eq("aaa@remote")
      end
    end
  end

  describe ".display_handle" do
    it "returns the href" do
      expect(described_class.display_handle("https://remote/users/foo")).to eq("https://remote/users/foo")
    end

    context "given a mention" do
      let_build(:object)
      let_create!(:mention, named: nil, name: "foo@other", href: "https://remote/users/foo", subject: object)

      it "returns the mention name" do
        expect(described_class.display_handle("https://remote/users/foo")).to eq("foo@other")
      end

      context "and an actor" do
        let_create!(:actor, iri: "https://remote/users/foo", username: "foo")

        it "returns the actor's handle" do
          expect(described_class.display_handle("https://remote/users/foo")).to eq("foo@remote")
        end
      end
    end
  end

  describe ".qualified_handles" do
    create_object_with_mentions(1, "foo@remote", "foo@other", "bar@remote")
    create_object_with_mentions(2, "foo@remote")

    it "returns empty when no handle matches" do
      expect(described_class.qualified_handles("nobody")).to be_empty
    end

    it "returns the distinct qualified handles" do
      expect(described_class.qualified_handles("bar")).to contain_exactly("bar@remote")
    end

    it "returns the distinct qualified handles" do
      expect(described_class.qualified_handles("foo").sort).to eq(["foo@other", "foo@remote"])
    end

    it "ignores handles whose tags have no href" do
      described_class.new(name: "ghost@remote", href: nil, subject: object1).save
      expect(described_class.qualified_handles("ghost")).to be_empty
    end

    create_object_with_mentions(1, "fo_o@remote", "foXo@remote", "fo%o@remote", "foXXXo@remote")

    it "treats '_' as a literal character" do
      expect(described_class.qualified_handles("fo_o")).to eq(["fo_o@remote"])
    end

    it "treats '%' as a literal character" do
      expect(described_class.qualified_handles("fo%o")).to eq(["fo%o@remote"])
    end
  end
end
