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

  describe ".find_or_new" do
    it "instantiates a new task" do
      expect(described_class.find_or_new(**options).new_record?).to be_true
    end

    context "given an existing task" do
      subject! { described_class.new(**options).save }

      it "finds the existing task" do
        expect(described_class.find_or_new(**options)).to eq(subject)
      end
    end
  end

  describe "#complete!" do
    subject { described_class.new(**options).save }

    it "makes the task not runnable" do
      expect{subject.complete!}.to change{subject.reload!.runnable?}.to(false)
    end
  end

  describe ".merge_into" do
    subject { described_class.new(**options).save }

    it "updates task if thread changes" do
      expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{subject.reload!.thread}.to("https://new_thread")
    end

    context "given another task for thread" do
      let_create!(:fetch_thread_task, source: subject.source, thread: "https://new_thread")

      it "merges the tasks" do
        expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{described_class.count}.by(-1)
      end

      it "destroys the task which would be changed" do
        expect{described_class.merge_into(subject.thread, "https://new_thread")}.to change{described_class.find?(subject.id)}.to(nil)
      end
    end
  end
end
