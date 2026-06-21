require "../../src/models/tag"
require "../../src/models/tag/hashtag"
require "../../src/models/tag/mention"
require "../../src/models/tag/emoji"

require "../spec_helper/base"
require "../spec_helper/factory"

# expose the private methods for direct testing
class Tag
  def full_recount
    previous_def
  end

  def update_count(difference)
    previous_def(difference)
  end

  def statistics_row_exists?
    previous_def
  end
end

Spectator.describe Tag do
  setup_spec

  class TagDouble < Tag
    class_property full_recount_count : Int64 = 0
    class_property update_count_count : Int64 = 0

    def self.reset_counts
      @@full_recount_count = 0
      @@update_count_count = 0
    end

    def full_recount
      self.class.full_recount_count += 1
    end

    def update_count(difference)
      self.class.update_count_count += 1
    end
  end

  before_each { TagDouble.reset_counts }

  def insert_statistics_row(tag)
    Ktistec.database.exec(
      "INSERT INTO tag_statistics (type, name, count) VALUES (?, ?, ?)",
      tag.short_type, tag.name, 0,
    )
  end

  describe "#statistics_row_exists?" do
    let(tag) { TagDouble.new(subject_iri: "http://remote/thing", name: "foobar") }

    it "matches the name" do
      Ktistec.database.exec(
        "INSERT INTO tag_statistics (type, name, count) VALUES (?, ?, ?)",
        tag.short_type, "FOOBAR", 0,
      )
      expect(tag.statistics_row_exists?).to be_true
    end

    it "is scoped by short type" do
      Ktistec.database.exec(
        "INSERT INTO tag_statistics (type, name, count) VALUES (?, ?, ?)",
        "other_type", tag.name, 0,
      )
      expect(tag.statistics_row_exists?).to be_false
    end
  end

  describe "#after_create" do
    let(tag) { TagDouble.new(subject_iri: "http://remote/thing", name: "foobar") }

    context "when no statistics row exists" do
      pre_condition { expect(tag.statistics_row_exists?).to be_false }

      it "calls `full_recount`" do
        expect { tag.after_create }.to change { TagDouble.full_recount_count }.by(1)
      end

      it "does not call `update_count`" do
        expect { tag.after_create }.not_to change { TagDouble.update_count_count }
      end
    end

    context "when a statistics row exists" do
      before_each { insert_statistics_row(tag) }

      pre_condition { expect(tag.statistics_row_exists?).to be_true }

      it "calls `update_count`" do
        expect { tag.after_create }.to change { TagDouble.update_count_count }.by(1)
      end

      it "does not call `full_recount`" do
        expect { tag.after_create }.not_to change { TagDouble.full_recount_count }
      end
    end
  end

  describe "#after_destroy" do
    let(tag) { TagDouble.new(subject_iri: "http://remote/thing", name: "foobar") }

    context "when no statistics row exists" do
      pre_condition { expect(tag.statistics_row_exists?).to be_false }

      it "calls `full_recount`" do
        expect { tag.after_destroy }.to change { TagDouble.full_recount_count }.by(1)
      end

      it "does not call `update_count`" do
        expect { tag.after_destroy }.not_to change { TagDouble.update_count_count }
      end
    end

    context "when a statistics row exists" do
      before_each { insert_statistics_row(tag) }

      pre_condition { expect(tag.statistics_row_exists?).to be_true }

      it "calls `update_count`" do
        expect { tag.after_destroy }.to change { TagDouble.update_count_count }.by(1)
      end

      it "does not call `full_recount`" do
        expect { tag.after_destroy }.not_to change { TagDouble.full_recount_count }
      end
    end
  end

  describe "#save" do
    let!(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar") }

    it "increments the count" do
      expect { tag.save }.to change { described_class.count(name: "foobar") }.by(1)
    end
  end

  describe "#destroy" do
    let!(tag) { described_class.new(subject_iri: "http://remote/thing", name: "foobar").save }

    it "decrements the count" do
      expect { tag.destroy }.to change { described_class.count(name: "foobar") }.by(-1)
    end
  end

  # the count is observable only through a read path, so `.match` is the oracle.

  describe "#full_recount" do
    let_create!(:object, published: Time.local)
    let_create!(:tag, subject_iri: object.iri, name: "foobar")

    context "when the object isn't published" do
      before_each { object.assign(published: nil).save }

      it "excludes it from the count" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    context "when the object is deleted" do
      before_each { object.delete! }

      it "excludes it from the count" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    context "when the object is blocked" do
      before_each { object.block! }

      it "excludes it from the count" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    context "when the actor is deleted" do
      before_each { object.attributed_to.delete! }

      it "excludes it from the count" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    context "when the actor is blocked" do
      before_each { object.attributed_to.block! }

      it "excludes it from the count" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    context "when the object is special" do
      before_each { object.assign(special: "vote").save }

      it "excludes it from the count" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    context "when a post repeats the same tag" do
      let_create!(:tag, named: nil, subject_iri: object.iri, name: "foobar")

      it "counts the object once" do
        expect { tag.full_recount }.to change { Tag.match("foobar") }.from([{"foobar", 2}]).to([{"foobar", 1}])
      end
    end
  end

  describe "#update_count" do
    let_create!(:object, published: Time.local)
    let_create!(:tag, subject_iri: object.iri, name: "foobar")

    pre_condition { expect(Tag.match("foobar")).to eq([{"foobar", 1}]) }

    it "applies the delta" do
      expect { tag.update_count(1) }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 2}])
    end

    context "when the object isn't published" do
      before_each { object.assign(published: nil).save }

      it "does not apply the delta" do
        expect { tag.update_count(1) }.not_to change { Tag.match("foobar") }
      end
    end

    context "when the object is deleted" do
      before_each { object.delete! }

      it "does not apply the delta" do
        expect { tag.update_count(1) }.not_to change { Tag.match("foobar") }
      end
    end

    context "when the object is blocked" do
      before_each { object.block! }

      it "does not apply the delta" do
        expect { tag.update_count(1) }.not_to change { Tag.match("foobar") }
      end
    end

    context "when the actor is deleted" do
      before_each { object.attributed_to.delete! }

      it "does not apply the delta" do
        expect { tag.update_count(1) }.not_to change { Tag.match("foobar") }
      end
    end

    context "when the actor is blocked" do
      before_each { object.attributed_to.block! }

      it "does not apply the delta" do
        expect { tag.update_count(1) }.not_to change { Tag.match("foobar") }
      end
    end

    context "when the object is special" do
      before_each { object.assign(special: "vote").save }

      it "does not apply the delta" do
        expect { tag.update_count(1) }.not_to change { Tag.match("foobar") }
      end
    end
  end

  describe ".reconcile_statistics" do
    # a published object carrying one hashtag. its cache row is created
    # by the fast path on tag creation, so the steady state is one
    # `(hashtag, foobar)` row at the true count of 1.
    let_create!(:object, published: Time.local)
    let_create!(:hashtag, subject_iri: object.iri, name: "foobar")

    it "corrects nothing" do
      expect(Tag::Hashtag.all_objects_count("foobar")).to eq(1)
      expect(Tag.reconcile_statistics).to eq({inserted: 0, updated: 0, zeroed: 0})
    end

    context "when a cached count has drifted" do
      before_each do
        Ktistec.database.exec(
          "UPDATE tag_statistics SET count = ? WHERE type = ? AND name = ?", 99, "hashtag", "foobar",
        )
      end

      it "corrects the count" do
        expect { Tag.reconcile_statistics }.to change { Tag::Hashtag.all_objects_count("foobar") }.from(99).to(1)
      end

      it "counts it as updated" do
        expect(Tag.reconcile_statistics).to eq({inserted: 0, updated: 1, zeroed: 0})
      end
    end

    context "when a qualifying key has no cache row" do
      before_each do
        Ktistec.database.exec(
          "DELETE FROM tag_statistics WHERE type = ? AND name = ?", "hashtag", "foobar",
        )
      end

      it "inserts the count" do
        expect { Tag.reconcile_statistics }.to change { Tag::Hashtag.all_objects_count("foobar") }.from(0).to(1)
      end

      it "counts it as inserted" do
        expect(Tag.reconcile_statistics).to eq({inserted: 1, updated: 0, zeroed: 0})
      end
    end

    context "when a key no longer qualifies" do
      before_each { object.attributed_to.block! }

      it "zeroes the count" do
        expect { Tag.reconcile_statistics }.to change { Tag::Hashtag.all_objects_count("foobar") }.from(1).to(0)
      end

      it "counts it as zeroed" do
        expect(Tag.reconcile_statistics).to eq({inserted: 0, updated: 0, zeroed: 1})
      end
    end

    context "when an orphaned key is already at zero" do
      before_each do
        Ktistec.database.exec(
          "INSERT INTO tag_statistics (type, name, count) VALUES (?, ?, ?)", "hashtag", "staletag", 0,
        )
      end

      pre_condition { expect(Tag::Hashtag.match("staletag")).to eq([{"staletag", 0}]) }

      it "skips it" do
        expect(Tag.reconcile_statistics).to eq({inserted: 0, updated: 0, zeroed: 0})
      end
    end

    context "given a mention without a cache row" do
      let_create!(:mention, named: mention_tag, subject_iri: object.iri, name: "someone")

      before_each do
        Ktistec.database.exec(
          "DELETE FROM tag_statistics WHERE type = ? AND name = ?", "mention", "someone",
        )
      end

      it "reconciles the tracked type" do
        expect { Tag.reconcile_statistics }.to change { Tag::Mention.all_objects_count("someone") }.from(0).to(1)
      end
    end

    context "given an untracked type without a cache row" do
      let_create!(:emoji, named: emoji_tag, subject_iri: object.iri, name: "smile", href: "https://test.test/smile.png")

      before_each do
        Ktistec.database.exec(
          "DELETE FROM tag_statistics WHERE type = ? AND name = ?", "emoji", "smile",
        )
      end

      pre_condition { expect(Tag::Emoji.match("smile")).to be_empty }

      it "does not reconcile it" do
        expect { Tag.reconcile_statistics }.not_to change { Tag::Emoji.match("smile") }
      end
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
