require "../../src/models/tag"

require "../spec_helper/base"

Spectator.describe Tag do
  setup_spec

  context "#save" do
    let(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar") }

    it "increments the count" do
      expect{tag.save}.to change{tag.count.as(Int64)}.by(1)
    end
  end

  context "#destroy" do
    let(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar").save }

    it "decrements the count" do
      expect{tag.destroy}.to change{tag.count.as(Int64)}.by(-1)
    end
  end

  context ".match" do
    class FooBarTag < Tag
    end

    macro create_tag(name)
      FooBarTag.new(subject_iri: "http://remote/thing/#{random_string}", name: {{name}}).save
    end

    before_each do
      create_tag("foobar")
      create_tag("foobar")
      create_tag("foo")
      create_tag("quux")
    end

    it "returns the best match" do
      expect(FooBarTag.match("foo")).to eq([{"foobar", 2}])
    end

    it "returns no match" do
      expect(FooBarTag.match("bar")).to be_empty
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
