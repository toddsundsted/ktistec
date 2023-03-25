require "../../../../src/models/task/fetch/thread"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Task::Fetch::Thread do
  setup_spec

  let_create(:actor, named: :source, with_keys: true)

  let(options) do
    {
      source_iri: source.iri,
      subject_iri: "https://#{random_string}"
    }
  end

  context "validation" do
    it "rejects missing source" do
      new_task = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain_exactly("source")
    end

    it "rejects blank thread" do
      new_task = described_class.new(**options.merge({subject_iri: ""}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain("thread")
    end

    it "successfully validates instance" do
      new_task = described_class.new(**options)
      expect(new_task.valid?).to be_true
    end
  end

  describe "#thread=" do
    subject { described_class.new(**options) }

    it "sets subject_iri" do
      expect{subject.assign(thread: "https://thread")}.to change{subject.subject_iri}
    end
  end

  describe "#thread" do
    subject { described_class.new(**options) }

    it "gets subject_iri" do
      expect(subject.thread).to eq(subject.subject_iri)
    end
  end
end
