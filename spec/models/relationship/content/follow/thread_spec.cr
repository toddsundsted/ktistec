require "../../../../../src/models/relationship/content/follow/thread"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Follow::Thread do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: "https://#{random_string}"
    }
  end

  context "validation" do
    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("actor")
    end

    it "rejects blank thread" do
      new_relationship = described_class.new(**options.merge({to_iri: ""}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("thread")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#thread=" do
    subject { described_class.new(**options) }

    it "sets to_iri" do
      expect{subject.assign(thread: "https://thread")}.to change{subject.to_iri}
    end
  end

  describe "#thread" do
    subject { described_class.new(**options) }

    it "gets to_iri" do
      expect(subject.thread).to eq(subject.to_iri)
    end
  end

  describe ".find_or_new" do
    let_create!(:object, named: :origin)
    let_create!(:object, named: :reply, iri: options[:to_iri], in_reply_to_iri: origin.iri)

    context "given an existing relationship for thread" do
      let(new_options) { {from_iri: options[:from_iri], thread: options[:to_iri]} }

      let!(existing) { described_class.new(**new_options).assign(thread: origin.thread).save }

      it "finds the existing follow" do
        expect(described_class.find_or_new(**new_options)).to eq(existing)
      end

      it "finds the existing follow" do
        expect(described_class.find_or_new(new_options.to_h.transform_keys(&.to_s))).to eq(existing)
      end
    end

    context "given an existing relationship for thread" do
      let!(existing) { described_class.new(**options).assign(to_iri: origin.thread).save }

      it "finds the existing follow" do
        expect(described_class.find_or_new(**options)).to eq(existing)
      end

      it "finds the existing follow" do
        expect(described_class.find_or_new(options.to_h.transform_keys(&.to_s))).to eq(existing)
      end
    end
  end

  describe ".merge_into" do
    subject { described_class.new(**options).save }

    it "updates relationship if thread changes" do
      expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{subject.reload!.thread}.to("https://new_thread")
    end

    context "given an existing relationship for thread" do
      let_create!(:follow_thread_relationship, named: existing, actor: subject.actor, thread: "https://new_thread")

      it "merges the relationships" do
        expect{described_class.merge_into(subject.thread, existing.thread)}.to change{described_class.count}.by(-1)
      end

      it "destroys the relationship which is merged from" do
        expect{described_class.merge_into(subject.thread, existing.thread)}.to change{described_class.find?(subject.id)}.to(nil)
      end

      it "does not destroy the relationship which is merged to" do
        expect{described_class.merge_into(subject.thread, existing.thread)}.not_to change{described_class.find?(existing.id)}
      end
    end
  end
end

Spectator.describe ActivityPub::Object do
  setup_spec

  context "given a follow" do
    let_build(:object)
    let_build(:actor)
    let_create!(:follow_thread_relationship, named: nil, actor: actor, thread: object.save.thread)

    def all_follows ; Relationship::Content::Follow::Thread.all end

    it "updates follow relationships when thread changes" do
      expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_follows.map(&.to_iri)}.to(["https://elsewhere"])
    end

    context "given an existing follow relationship" do
      let_create!(:follow_thread_relationship, named: nil, actor: actor, thread: "https://elsewhere")

      it "updates follow relationships when thread changes" do
        expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_follows.map(&.to_iri)}.to(["https://elsewhere"])
      end
    end
  end
end
