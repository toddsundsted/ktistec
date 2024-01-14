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

class FooBarTask < Task
  class_property performed = [] of Int64

  def perform
    FooBarTask.performed << self.id.not_nil!
  end
end

class DestroyTask < Task
  def initialize(options = Hash(String, String).new)
    options = {
      "source_iri" => "https://test.test/source",
      "subject_iri" => "https://test.test/subject"
    }.merge(options)
    super(options)
  end

  # destroy the saved record, but intentionally do not change the
  # instance, itself.

  def perform
    self.class.find(@id).destroy
  end
end

class ExceptionTask < Task
  def initialize(options = Hash(String, String).new)
    options = {
      "source_iri" => "https://test.test/source",
      "subject_iri" => "https://test.test/subject"
    }.merge(options)
    super(options)
  end

  # raise an exception.

  def perform
    nil.not_nil!
  end
end

class RescheduleTask < Task
  def initialize(options = Hash(String, String).new)
    options = {
      "source_iri" => "https://test.test/source",
      "subject_iri" => "https://test.test/subject"
    }.merge(options)
    super(options)
  end

  def perform
    self.next_attempt_at = Time.utc + 10.seconds
  end
end

Spectator.describe TaskWorker do
  setup_spec

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

  create_task!(1, Time.utc(2016, 2, 15, 10, 20, 8))
  create_task!(2, Time.utc(2016, 2, 15, 10, 20, 4))
  create_task!(3, Time.utc(2016, 2, 15, 10, 20, 6))
  create_task!(4, Time.utc(2016, 2, 15, 10, 20, 2))
  create_task!(5)

  let(now) { Time.utc(2016, 2, 15, 10, 20, 7) }

  describe "#work" do
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

    it "sets complete to true" do
      described_class.new.work(now)
      expect(task5.reload!.complete).to be_true
    end

    it "sets complete to true unless task wasn't scheduled" do
      described_class.new.work(now)
      expect(task1.reload!.complete).to be_false
    end

    it "sets complete to true unless task throws an uncaught exception" do
      task = ExceptionTask.new.save
      described_class.new.work(now)
      expect(task.reload!.complete).to be_false
    end

    it "sets complete to true unless task is rescheduled" do
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

  describe ".destroy_old_tasks" do
    it "destroys old complete tasks" do
      task5.assign(complete: true, created_at: now).save
      expect{TaskWorker.destroy_old_tasks}.to change{Task.count}.by(-1)
    end

    it "destroys old failed tasks" do
      task5.assign(backtrace: [""], created_at: now).save
      expect{TaskWorker.destroy_old_tasks}.to change{Task.count}.by(-1)
    end

    it "ignores new tasks" do
      task5.assign(complete: true, backtrace: [""]).save
      expect{TaskWorker.destroy_old_tasks}.not_to change{Task.count}
    end
  end

  describe ".clean_up_running_tasks" do
    it "sets running tasks to not running" do
      task5.assign(running: true).save
      expect{TaskWorker.clean_up_running_tasks}.to change{Task.count(running: true)}.by(-1)
    end
  end
end
