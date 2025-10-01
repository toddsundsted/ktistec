require "../../../../src/models/task"
require "../../../../src/models/task/mixins/singleton"

require "../../../spec_helper/base"

class SingletonTask < Task
  include Task::Singleton

  def perform
    # no-op
  ensure
    self.next_attempt_at = 1.day.from_now
  end
end

Spectator.describe Task::Singleton do
  setup_spec

  describe ".find_active" do
    it "returns nil when no tasks exist" do
      expect(SingletonTask.find_active).to be_nil
    end

    context "when a runnable task exists" do
      let!(task) { SingletonTask.new.save }

      it "returns the task" do
        expect(SingletonTask.find_active).to eq(task)
      end
    end

    context "when a running task exists" do
      let!(task) { SingletonTask.new.assign(running: true).save }

      it "returns the task" do
        expect(SingletonTask.find_active).to eq(task)
      end
    end

    context "when a complete task exists" do
      let!(task) { SingletonTask.new.assign(complete: true).save }

      it "returns nil" do
        expect(SingletonTask.find_active).to be_nil
      end
    end

    context "when a failed task exists" do
      let!(task) { SingletonTask.new.assign(backtrace: ["error"]).save }

      it "returns nil" do
        expect(SingletonTask.find_active).to be_nil
      end
    end

    context "when multiple active tasks exist" do
      let!(task1) { SingletonTask.new.save }
      let!(task2) { SingletonTask.new.assign(running: true).save }

      it "returns the most recent task" do
        expect(SingletonTask.find_active).to eq(task2)
      end
    end
  end

  describe ".current_instance" do
    it "returns a SingletonTask instance" do
      expect(SingletonTask.current_instance).to be_a(SingletonTask)
    end

    it "creates a new instance when none exists" do
      expect { SingletonTask.current_instance }.to change { SingletonTask.count }.by(1)
    end

    context "when a running task exists" do
      let!(task) { SingletonTask.new.assign(running: true).save }

      it "does not create a new instance" do
        expect { SingletonTask.current_instance }.not_to change { SingletonTask.count }
      end

      it "returns the running task" do
        expect(SingletonTask.current_instance).to eq(task)
      end
    end

    context "when a runnable task exists" do
      let!(task) { SingletonTask.new.save }

      it "does not create a new instance" do
        expect { SingletonTask.current_instance }.not_to change { SingletonTask.count }
      end

      it "returns the existing runnable task" do
        expect(SingletonTask.current_instance).to eq(task)
      end
    end

    context "when only non-runnable tasks exist" do
      let!(complete_task) { SingletonTask.new.assign(complete: true).save }
      let!(failed_task) { SingletonTask.new.assign(backtrace: ["error"]).save }

      it "creates a new runnable instance" do
        expect { SingletonTask.current_instance }.to change { SingletonTask.count }.by(1)
      end

      it "returns a runnable task" do
        task = SingletonTask.current_instance
        expect(task.runnable?).to be_true
      end
    end

    context "when multiple runnable tasks exist" do
      let!(task1) { SingletonTask.new.save }
      let!(task2) { SingletonTask.new.assign(running: true).save }

      it "returns the most recent task" do
        expect(SingletonTask.current_instance).to eq(task2)
      end
    end
  end

  describe ".ensure_scheduled" do
    # NOTE: when running tests `Task#schedule` immediately invokes
    # `Task#perform`. Check `next_attempt_at` to verify the task was
    # scheduled.

    def scheduled?(task)
      (next_attempt_at = task.next_attempt_at) && next_attempt_at > 5.minutes.from_now
    end

    it "schedules the task" do
      SingletonTask.ensure_scheduled
      expect(scheduled?(SingletonTask.current_instance)).to be_true
    end

    it "creates a new instance when none exists" do
      expect { SingletonTask.ensure_scheduled }.to change { SingletonTask.count }.by(1)
    end

    context "when a running task exists" do
      let!(task) { SingletonTask.new.assign(running: true).save }

      it "does not raise an error" do
        expect { SingletonTask.ensure_scheduled }.not_to raise_error
      end

      it "does not create a new task" do
        expect { SingletonTask.ensure_scheduled }.not_to change { SingletonTask.count }
      end

      it "returns the existing running task as current_instance" do
        SingletonTask.ensure_scheduled
        expect(SingletonTask.current_instance).to eq(task)
      end
    end

    context "when called multiple times" do
      it "is idempotent" do
        SingletonTask.ensure_scheduled
        first_task = SingletonTask.current_instance
        SingletonTask.ensure_scheduled
        second_task = SingletonTask.current_instance
        expect(first_task).to eq(second_task)
      end
    end
  end
end
