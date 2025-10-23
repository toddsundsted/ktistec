require "../../src/models/tag"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Tag do
  setup_spec

  class TagDouble < Tag
    class_property full_recount_count : Int64 = 0
    class_property update_count_count : Int64 = 0

    def self.reset_counts
      @@full_recount_count = 0
      @@update_count_count = 0
    end

    private def full_recount
      self.class.full_recount_count += 1
    end

    private def update_count(difference)
      self.class.update_count_count += 1
    end
  end

  before_each { TagDouble.reset_counts }

  describe "#after_create" do
    context "when called 10 times" do
      before_each do
        10.times { TagDouble.new(subject_iri: "http://remote/thing", name: "foobar").after_create }
      end

      it "calls `full_recount` once" do
        expect(TagDouble.full_recount_count).to eq(1)
      end

      it "calls `update_count` 9 times" do
        expect(TagDouble.update_count_count).to eq(9)
      end
    end
  end

  describe "#after_destroy" do
    context "when called 10 times" do
      before_each do
        10.times { TagDouble.new(subject_iri: "http://remote/thing", name: "foobar").after_destroy }
      end

      it "calls `full_recount` once" do
        expect(TagDouble.full_recount_count).to eq(1)
      end

      it "calls `update_count` 9 times" do
        expect(TagDouble.update_count_count).to eq(9)
      end
    end
  end

  describe "#save" do
    let!(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar") }

    it "increments the count" do
      expect{tag.save}.to change{described_class.count(name: "foobar")}.by(1)
    end
  end

  describe "#destroy" do
    let!(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar").save }

    it "decrements the count" do
      expect{tag.destroy}.to change{described_class.count(name: "foobar")}.by(-1)
    end
  end

  describe ".match" do
    macro create_tag(index, name)
      let_create!(:object, named: object{{index}}, published: {{index}}.days.ago)
      let_create!(:tag, named: tag{{index}}, subject_iri: object{{index}}.iri, name: {{name}})
    end

    create_tag(1, "foobar")
    create_tag(2, "FooBar")
    create_tag(3, "foo")
    create_tag(4, "quux")

    it "returns the best match" do
      expect(Tag.match("foo")).to eq([{"foobar", 2}])
    end

    it "returns no match" do
      expect(Tag.match("bar")).to be_empty
    end

    context "with SQL wildcard character in prefix" do
      create_tag(5, "test_tag")
      create_tag(6, "test%special")

      it "treats underscore as literal character" do
        results = Tag.match("test_")
        expect(results).to contain({"test_tag", 1})
      end

      it "treats percent as literal character" do
        results = Tag.match("test%")
        expect(results).to contain({"test%special", 1})
      end
    end

    let_create(:object, published: Time.local)
    let_build(:tag, subject_iri: object.iri, name: "foobar")

    context "full recount logic" do
      # invalidate the cache after to ensure the test hits
      # `#full_recount`

      before_each { Tag.cache.clear }

      context "an object isn't published" do
        before_each do
          object.assign(published: nil).save
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an object is deleted" do
        before_each do
          object.delete!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an object is blocked" do
        before_each do
          object.block!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an actor is deleted" do
        before_each do
          object.attributed_to.delete!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an actor is blocked" do
        before_each do
          object.attributed_to.block!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end
    end

    context "update count logic" do
      # tests hit `#update_count`

      context "an object isn't published" do
        before_each do
          object.assign(published: nil).save
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an object is deleted" do
        before_each do
          object.delete!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an object is blocked" do
        before_each do
          object.block!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an actor is deleted" do
        before_each do
          object.attributed_to.delete!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
      end

      context "an actor is blocked" do
        before_each do
          object.attributed_to.block!
          tag.save
        end

        it "returns the match" do
          expect(Tag.match("foo", 2)).to have({"foobar", 2})
        end
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
