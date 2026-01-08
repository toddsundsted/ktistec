require "../../src/models/task"
require "../../src/models/task/mixins/singleton"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Task do
  setup_spec

  class Task < ::Task
    def perform
      # no-op
    end

    # expose protected method for testing
    def randomized_next_attempt_at(delta : Time::Span, randomization_percentage : Float64? = nil) : Time
      super
    end
  end

  subject do
    Task.new(
      source_iri: "https://test.test/source",
      subject_iri: "https://test.test/subject"
    )
  end

  describe ".ensure_scheduled" do
    class SingletonTask < ::Task
      include ::Task::Singleton

      def perform
        # no-op
      end
    end

    let(future_time) { 1.day.from_now }

    let!(task) { SingletonTask.new.assign(next_attempt_at: future_time).save }

    it "does not reset next_attempt_at" do
      SingletonTask.ensure_scheduled
      expect(task.reload!.next_attempt_at).to be_close(future_time.to_utc, delta: 1.millisecond)
    end
  end

  describe "#gone?" do
    it "is false if the task is saved" do
      expect(subject.save.gone?).to be_false
    end

    it "is true if the saved task is destroyed" do
      expect(subject.save.tap(&.destroy).gone?).to be_true
    end

    it "is true if the task is not saved" do
      expect(subject.gone?).to be_true
    end
  end

  describe "#runnable?" do
    it "is true if running is false, complete is false and backtrace is nil" do
      subject.assign(running: false, complete: false, backtrace: nil)
      expect(subject.runnable?).to be_true
    end

    it "is false if running is true" do
      subject.assign(running: true, complete: false, backtrace: nil)
      expect(subject.runnable?).to be_false
    end

    it "is false if complete is true" do
      subject.assign(running: false, complete: true, backtrace: nil)
      expect(subject.runnable?).to be_false
    end

    it "is false if backtrace is not nil" do
      subject.assign(running: false, complete: false, backtrace: [""])
      expect(subject.runnable?).to be_false
    end
  end

  describe "#past_due?" do
    it "is true if next_attempt_at is nil" do
      subject.next_attempt_at = nil
      expect(subject.past_due?).to be_true
    end

    it "is true if next_attempt_at is in the past" do
      subject.next_attempt_at = 1.day.ago
      expect(subject.past_due?).to be_true
    end

    it "is false if next_attempt_at is in the future" do
      subject.next_attempt_at = 1.day.from_now
      expect(subject.past_due?).to be_false
    end
  end

  describe "#randomized_next_attempt_at" do
    let(now) { Time.utc }

    it "returns exact time for deltas less than minimum threshold" do
      delta = 4.minutes
      result = subject.randomized_next_attempt_at(delta)
      expected = delta.from_now
      expect(result).to be_close(expected, delta: 1.second)
    end

    it "returns randomized time for delta equal to minimum threshold" do
      delta = Task::MIN_RANDOMIZATION_THRESHOLD
      result = subject.randomized_next_attempt_at(delta)
      expected = delta.from_now
      max_variation = delta.total_seconds * Task::ADAPTIVE_RANDOMIZATION_PERCENTAGE_SHORT / 2.0
      time_diff = (result - expected).total_seconds.abs
      expect(time_diff).to be <= max_variation
    end

    it "uses short adaptive percentage for intervals < 6 hours" do
      delta = 1.hour
      result = subject.randomized_next_attempt_at(delta)
      expected = delta.from_now
      max_variation = delta.total_seconds * Task::ADAPTIVE_RANDOMIZATION_PERCENTAGE_SHORT / 2.0
      time_diff = (result - expected).total_seconds.abs
      expect(time_diff).to be <= max_variation
    end

    it "uses long adaptive percentage for intervals >= 6 hours" do
      delta = 1.day
      result = subject.randomized_next_attempt_at(delta)
      expected = delta.from_now
      max_variation = delta.total_seconds * Task::ADAPTIVE_RANDOMIZATION_PERCENTAGE_LONG / 2.0
      time_diff = (result - expected).total_seconds.abs
      expect(time_diff).to be <= max_variation
    end

    it "uses explicit randomization percentage when provided" do
      delta = 1.hour
      custom_percentage = 0.10 # 10%
      result = subject.randomized_next_attempt_at(delta, randomization_percentage: custom_percentage)
      expected = delta.from_now
      max_variation = delta.total_seconds * custom_percentage / 2.0
      time_diff = (result - expected).total_seconds.abs
      expect(time_diff).to be <= max_variation
    end
  end

  describe "#schedule" do
    it "raises an error if the task is running" do
      subject.running = true
      expect { subject.schedule }.to raise_error(Exception)
    end

    it "raises an error if the task has a backtrace" do
      subject.backtrace = [""]
      expect { subject.schedule }.to raise_error(Exception)
    end

    it "sets the next_attempt_at if specified" do
      time = 1.day.from_now
      expect { subject.schedule(time) }.to change { subject.next_attempt_at }
    end

    it "saves the task" do
      expect { subject.schedule }.to change { Task.count }
    end
  end

  describe ".scheduled" do
    macro create_task!(index, next_attempt_at = nil)
      let!(task{{index}}) do
        described_class.new(
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
    create_task!(5) # perform immediately
    create_task!(6)
    create_task!(7)

    before_each do
      task6.assign(running: true).save
      task7.assign(complete: true).save
    end

    let(now) { Time.utc(2016, 2, 15, 10, 20, 7) }

    it "returns the scheduled tasks in priority order" do
      expect(described_class.scheduled(now, false)).to eq([task5, task4, task2, task3])
    end

    it "does not reserve the scheduled tasks" do
      expect(described_class.scheduled(now, false).none?(&.running)).to be_true
    end

    it "returns the scheduled tasks in priority order" do
      expect(described_class.scheduled(now, true)).to eq([task5, task4, task2, task3])
    end

    it "reserves the scheduled tasks" do
      expect(described_class.scheduled(now, true).all?(&.running)).to be_true
    end

    context "with old tasks" do
      let!(recent_completed_task) do
        described_class.new(
          source_iri: "https://test.test/source",
          subject_iri: "https://test.test/recent-completed",
          complete: true,
          backtrace: nil,
          created_at: now - 1.hour,
        ).save
      end
      let!(old_completed_task) do
        described_class.new(
          source_iri: "https://test.test/source",
          subject_iri: "https://test.test/old-completed",
          complete: true,
          backtrace: nil,
          created_at: now - 3.hours,
        ).save
      end
      let!(old_failed_task) do
        described_class.new(
          source_iri: "https://test.test/source",
          subject_iri: "https://test.test/old-failed",
          complete: true,
          backtrace: ["error"],
          created_at: now - 3.hours,
        ).save
      end

      it "preserves recent completed tasks" do
        described_class.scheduled(now, true)
        expect(Task.find?(recent_completed_task.id)).not_to be_nil
      end

      it "deletes old completed tasks" do
        expect { described_class.scheduled(now, true) }.to change { Task.count }.by(-1)
        expect(Task.find?(old_completed_task.id)).to be_nil
      end

      it "preserves old completed tasks with backtraces" do
        described_class.scheduled(now, true)
        expect(Task.find?(old_failed_task.id)).not_to be_nil
      end

      it "does not delete when not reserving" do
        expect { described_class.scheduled(now, false) }.not_to change { Task.count }
      end
    end
  end

  describe ".running_count" do
    it "returns 0" do
      expect(::Task.running_count).to eq(0)
    end

    context "with mixed task states" do
      let_create!(:task, named: nil, running: true, complete: false)
      let_create!(:task, named: nil, running: false, complete: false)
      let_create!(:task, named: nil, running: true, complete: true)

      it "counts only running and incomplete tasks" do
        expect(::Task.running_count).to eq(1)
      end
    end
  end

  describe ".scheduled_soon_count" do
    let(fixed_time) { Time.utc(2024, 1, 1, 12, 0, 0) }

    it "returns 0" do
      expect(::Task.scheduled_soon_count).to eq(0)
    end

    context "with tasks" do
      let_create!(
        :task, named: nil,
        running: false,
        complete: false,
        next_attempt_at: 30.seconds.from_now,
      )

      let_create!(
        :task, named: nil,
        running: false,
        complete: false,
        next_attempt_at: 2.minutes.from_now,
      )

      it "counts tasks scheduled within 1 minute" do
        expect(::Task.scheduled_soon_count).to eq(1)
      end

      it "accepts custom time window" do
        expect(::Task.scheduled_soon_count(3.minutes)).to eq(2)
        expect(::Task.scheduled_soon_count(15.seconds)).to eq(0)
      end
    end

    context "with running task" do
      let_create!(
        :task,
        running: true,
        complete: false,
        next_attempt_at: 30.seconds.from_now,
      )

      it "does not count running tasks" do
        expect(::Task.scheduled_soon_count).to eq(0)
      end
    end

    context "with complete task" do
      let_create!(
        :task,
        running: false,
        complete: true,
        next_attempt_at: 30.seconds.from_now,
      )

      it "does not count complete tasks" do
        expect(::Task.scheduled_soon_count).to eq(0)
      end
    end

    context "with failed task" do
      let_create!(:task,
        running: false,
        complete: false,
        backtrace: ["error"],
        next_attempt_at: 30.seconds.from_now,
      )

      it "does not count failed tasks" do
        expect(::Task.scheduled_soon_count).to eq(0)
      end
    end
  end

  context "given a saved task" do
    subject { super.save }

    let(now) { Time.utc(2016, 2, 15, 10, 20, 7) }

    describe ".destroy_old_tasks" do
      it "destroys old complete tasks" do
        subject.assign(complete: true, created_at: now).save
        expect { described_class.destroy_old_tasks }.to change { Task.count }.by(-1)
      end

      it "destroys old failed tasks" do
        subject.assign(backtrace: [""], created_at: now).save
        expect { described_class.destroy_old_tasks }.to change { Task.count }.by(-1)
      end

      it "ignores recent tasks" do
        subject.assign(complete: true, backtrace: [""]).save
        expect { described_class.destroy_old_tasks }.not_to change { Task.count }.from(1)
      end
    end

    describe ".clean_up_running_tasks" do
      it "sets running tasks to not running" do
        subject.assign(running: true).save
        expect { described_class.clean_up_running_tasks }.to change { Task.count(running: true) }.by(-1)
      end
    end
  end
end

Spectator.describe Task::ConcurrentTask do
  setup_spec

  let_build(:concurrent_task)

  subject { concurrent_task }

  describe "#fiber_name" do
    subject { super.save }

    it "returns the name of the associated fiber" do
      expect(subject.fiber_name).to eq("#{subject.class}-#{subject.id}")
    end
  end

  describe "#fiber" do
    subject { super.save }

    it "returns nil" do
      expect(subject.fiber).to be_nil
    end

    context "given a fiber" do
      let!(fiber) do
        spawn(name: subject.fiber_name) do
          sleep 1.second
        end
      end

      it "returns the fiber" do
        expect(subject.fiber).to eq(fiber)
      end
    end
  end
end
