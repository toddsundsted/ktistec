require "../../src/workers/task_worker"

# note: when writing tests, be aware that when running tests,
# helper base extends `Task#schedule` to invoke `#perform`.
require "../spec_helper/base"

class TaskWorker
  # expose method for testing
  def work(now = Time.utc)
    previous_def(now)
  end
end

class BaseTask < Task
  def initialize(options = Hash(String, String).new)
    options = {
      "source_iri" => "https://test.test/#{random_string}",
      "subject_iri" => "https://test.test/#{random_string}"
    }.merge(options)
    super(options)
  end
end

class FooBarTask < Task
  class_property performed = [] of Int64

  def perform
    FooBarTask.performed << self.id.not_nil!
  end
end

class DestroyTask < BaseTask
  # destroy the saved record, but intentionally do not change the
  # instance, itself.

  def perform
    self.class.find(@id).destroy
  end
end

class ExceptionTask < BaseTask
  # raise an exception.

  def perform
    nil.not_nil!
  end
end

class ServerShutdownExceptionTask < BaseTask
  # raise a server shutdown exception.

  def perform
    raise TaskWorker::ServerShutdownException.new
  end
end

class RescheduleTask < BaseTask
  # reschedule the task.

  def perform
    self.next_attempt_at = Time.utc + 10.seconds
  end
end

class SleepTask < BaseTask
  @@schedule_but_dont_perform = true

  # sleep for a short time.

  def perform
    sleep 0.seconds
  end
end

Spectator.describe TaskWorker do
  setup_spec

  describe ".stop" do
    before_each do
      TaskWorker.start do
        # no-op
      end
    end

    # the following tests must call `TaskWorker.stop`

    it "signals the worker to stop" do
      expect { TaskWorker.stop }.to change { TaskWorker.running? }.from(true).to(false)
    end

    context "given a scheduled task" do
      let(task) { SleepTask.new.save.schedule }

      def spawn_and_yield
        spawn { TaskWorker.instance.perform(task) }
        Fiber.yield
      end

      it "waits for scheduled tasks to complete" do
        expect { spawn_and_yield ; TaskWorker.stop }.to change { task.reload!.complete }.from(false).to(true)
      end
    end
  end

  describe "#work" do
    before_each { FooBarTask.performed.clear }

    macro create_task!(index, next_attempt_at = nil)
      let!(task{{index}}) do
        FooBarTask.new(
          source_iri: "https://test.test/source",
          subject_iri: "https://test.test/subject",
          next_attempt_at: {{next_attempt_at}}
        ).save
      end
    end

    let(now) { Time.utc(2016, 2, 15, 10, 20, 7) }

    create_task!(1, now + 1.second)
    create_task!(2, now - 3.seconds)
    create_task!(3, now - 1.second)
    create_task!(4, now - 5.seconds)
    create_task!(5)

    it "calls perform on all scheduled tasks" do
      described_class.new.work(now)
      expect(FooBarTask.performed).to eq([task5.id, task4.id, task2.id, task3.id])
    end

    it "ensures task is not left running" do
      described_class.new.work(now)
      expect(task5.reload!.running).to be_false
    end

    it "does not resurrect a task that has been destroyed" do
      task = DestroyTask.new.save
      described_class.new.work(now)
      expect(task.gone?).to be_true
    end

    it "stores the backtrace when task throws an uncaught exception" do
      task = ExceptionTask.new.save
      described_class.new.work(now)
      expect(task.reload!.backtrace.not_nil!).to have(/Nil assertion failed/)
    end

    it "does not store the backtrace when task throws a server shutdown exception" do
      task = ServerShutdownExceptionTask.new.save
      described_class.new.work(now)
      expect(task.reload!.backtrace).to be_nil
    end

    it "sets complete to true" do
      described_class.new.work(now)
      expect(task5.reload!.complete).to be_true
    end

    it "leaves complete as false if task wasn't scheduled" do
      described_class.new.work(now)
      expect(task1.reload!.complete).to be_false
    end

    it "leaves complete as false if task throws an uncaught exception" do
      task = ExceptionTask.new.save
      described_class.new.work(now)
      expect(task.reload!.complete).to be_false
    end

    it "leaves complete as false if task is rescheduled" do
      task = RescheduleTask.new.save
      described_class.new.work(now)
      expect(task.reload!.complete).to be_false
    end

    it "sets last_attempt_at" do
      described_class.new.work(now)
      expect(task5.reload!.last_attempt_at.not_nil!).to be_close(Time.utc, 10.seconds)
    end

    it "returns true if work was done" do
      expect(described_class.new.work(now)).to be_true
    end

    it "returns false if work was not done" do
      task5.destroy
      expect(described_class.new.work(now - 1.day)).to be_false
    end
  end
end
