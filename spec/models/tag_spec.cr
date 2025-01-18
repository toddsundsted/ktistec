require "../../src/models/tag"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Tag do
  setup_spec

  context "#save" do
    let!(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar") }

    it "increments the count" do
      expect{tag.save}.to change{described_class.count(name: "foobar")}.by(1)
    end
  end

  context "#destroy" do
    let!(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar").save }

    it "decrements the count" do
      expect{tag.destroy}.to change{described_class.count(name: "foobar")}.by(-1)
    end
  end

  context ".match" do
    macro create_tag(index, name)
      let_create!(:object, named: object{{index}}, published: {{index}}.days.ago)
      let_create!(:tag, named: tag{{index}}, subject_iri: object{{index}}.iri, name: {{name}})
    end

    create_tag(1, "foobar")
    create_tag(2, "foobar")
    create_tag(3, "foo")
    create_tag(4, "quux")

    it "returns the best match" do
      expect(Tag.match("foo")).to eq([{"foobar", 2}])
    end

    it "returns no match" do
      expect(Tag.match("bar")).to be_empty
    end

    context "an object isn't published" do
      before_each do
        object1.assign(published: nil).save
        tag1.save
      end

      it "returns the match" do
        expect(Tag.match("foo", 2)).to have({"foobar", 1})
      end
    end

    context "an object is deleted" do
      before_each do
        object1.delete!
        tag1.save
      end

      it "returns the match" do
        expect(Tag.match("foo", 2)).to have({"foobar", 1})
      end
    end

    context "an object is blocked" do
      before_each do
        object1.block!
        tag1.save
      end

      it "returns the match" do
        expect(Tag.match("foo", 2)).to have({"foobar", 1})
      end
    end

    context "an actor is deleted" do
      before_each do
        object2.attributed_to.delete!
        tag2.save
      end

      it "returns the match" do
        expect(Tag.match("foo", 2)).to have({"foobar", 1})
      end
    end

    context "an actor is blocked" do
      before_each do
        object2.attributed_to.block!
        tag2.save
      end

      it "returns the match" do
        expect(Tag.match("foo", 2)).to have({"foobar", 1})
      end
    end
  end

  context "validations" do
    it "rejects if subject_iri is blank" do
      new_tag = described_class.new(name: "tag")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject_iri")
    end

    it "rejects if subject_iri is not an absolute URI" do
      new_tag = described_class.new(subject_iri: "/tag", name: "tag")
      expect(new_tag.valid?).to be_false
      expect(new_tag.errors.keys).to contain("subject_iri")
    end

    it "successfully validates instance" do
      new_tag = described_class.new(subject_iri: "https://test.test/tag", name: "tag")
      expect(new_tag.valid?).to be_true
    end
  end
end
