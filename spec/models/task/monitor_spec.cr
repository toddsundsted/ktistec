require "../../../src/models/task/monitor"

require "../../spec_helper/base"

Spectator.describe Task::Monitor do
  setup_spec

  describe "#running_tasks_without_fibers" do
    subject { described_class.new }

    it "returns an empty array" do
      expect(subject.running_tasks_without_fibers).to be_empty
    end

    context "given a running task" do
      class ConcurrentTask < ::Task
        include ::Task::ConcurrentTask

        def perform
          # no-op
        end
      end

      let!(task) do
        ConcurrentTask.new(
          source_iri: "https://test.test/source",
          subject_iri: "https://test.test/subject",
          running: true
        ).save
      end

      it "returns the task" do
        expect(subject.running_tasks_without_fibers).to have(task)
      end

      context "given a fiber" do
        let!(fiber) do
          spawn(name: task.fiber_name) do
            sleep 1
          end
        end

        it "does not return the task" do
          expect(subject.running_tasks_without_fibers).not_to have(task)
        end
      end
    end
  end

  describe "#perform" do
    subject { described_class.new }

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end
  end
end
