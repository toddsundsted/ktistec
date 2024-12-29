require "../../../src/models/task/monitor"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::Monitor do
  setup_spec

  describe "#running_tasks_without_fibers" do
    subject { described_class.new }

    it "returns an empty array" do
      expect(subject.running_tasks_without_fibers).to be_empty
    end

    context "given a running concurrent task" do
      let_create!(concurrent_task, named: task, running: true)

      it "returns the task" do
        expect(subject.running_tasks_without_fibers).to have(task)
      end

      context "given a fiber" do
        let!(fiber) do
          spawn(name: task.fiber_name) do
            sleep 1.second
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
