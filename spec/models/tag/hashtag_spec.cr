require "../../../src/models/tag/hashtag"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Tag::Hashtag do
  setup_spec

  context "creation" do
    let_build(:actor)
    let_build(:object)

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

  describe ".all_objects" do
    let_build(:actor, named: :author)

    macro create_tagged_object(index, *tags)
      let_create!(
        :object, named: object{{index}},
        attributed_to: author,
        published: Time.utc(2016, 2, 15, 10, 20, {{index}})
      )
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
      expect(described_class.all_objects("bar")).to eq([object3, object1])
    end

    it "filters out draft objects" do
      object5.assign(published: nil).save
      expect(described_class.all_objects("foo")).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete
      expect(described_class.all_objects("foo")).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block
      expect(described_class.all_objects("foo")).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete
      expect(described_class.all_objects("foo")).to be_empty
    end

    it "filters out objects with blocked attributed to actors" do
      author.block
      expect(described_class.all_objects("foo")).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.all_objects("foo")).to be_empty
    end

    it "paginates the results" do
      expect(described_class.all_objects("foo", 1, 2)).to eq([object5, object4])
      expect(described_class.all_objects("foo", 2, 2)).to eq([object3, object2])
      expect(described_class.all_objects("foo", 2, 2).more?).to be_true
    end
  end

  describe ".public_objects" do
    let_build(:actor, named: :author)

    macro create_tagged_object(index, *tags)
      let_create!(
        :object, named: object{{index}},
        attributed_to: author,
        published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
        local: true
      )
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
      expect(described_class.public_objects("bar")).to eq([object3, object1])
    end

    it "filters out non-published objects" do
      object5.assign(published: nil).save
      expect(described_class.public_objects("foo")).not_to have(object5)
    end

    it "filters out non-visible objects" do
      object5.assign(visible: false).save
      expect(described_class.public_objects("foo")).not_to have(object5)
    end

    it "filters out deleted objects" do
      object5.delete
      expect(described_class.public_objects("foo")).not_to have(object5)
    end

    it "filters out blocked objects" do
      object5.block
      expect(described_class.public_objects("foo")).not_to have(object5)
    end

    it "filters out objects with deleted attributed to actors" do
      author.delete
      expect(described_class.public_objects("foo")).to be_empty
    end

    it "filters out objects with blocked attributed to actors" do
      author.block
      expect(described_class.public_objects("foo")).to be_empty
    end

    it "filters out objects with destroyed attributed to actors" do
      author.destroy
      expect(described_class.public_objects("foo")).to be_empty
    end

    context "given a remote object" do
      let_create!(
        :object, named: :remote,
        published: Time.utc(2016, 2, 15, 10, 20, 10),
      )
      before_each do
        described_class.new(
          name: "foo",
          subject: remote
        ).save
      end

      it "filters out the object" do
        expect(described_class.public_objects("foo")).not_to have(remote)
      end

      context "that has been approved" do
        before_each { author.approve(remote) }

        it "includes the object" do
          expect(described_class.public_objects("foo")).to have(remote)
        end
      end
    end

    it "paginates the results" do
      expect(described_class.public_objects("foo", 1, 2)).to eq([object5, object4])
      expect(described_class.public_objects("foo", 2, 2)).to eq([object3, object2])
      expect(described_class.public_objects("foo", 2, 2).more?).to be_true
    end
  end
end
