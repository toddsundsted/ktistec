require "../../src/models/task"

require "../spec_helper/base"

Spectator.describe Task do
  setup_spec

  class Task < ::Task
    def perform
      # no-op
    end
  end

  subject do
    Task.new(
      source_iri: "https://test.test/source",
      subject_iri: "https://test.test/subject"
    )
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

  describe "#schedule" do
    it "raises an error if the task is running" do
      subject.running = true
      expect{subject.schedule}.to raise_error(Exception)
    end

    it "raises an error if the task has a backtrace" do
      subject.backtrace = [""]
      expect{subject.schedule}.to raise_error(Exception)
    end

    it "sets the next_attempt_at if specified" do
      time = 1.day.from_now
      expect{subject.schedule(time)}.to change{subject.next_attempt_at}
    end

    it "sets complete to false" do
      subject.complete = true
      expect{subject.schedule}.to change{subject.complete}.to(false)
    end

    it "saves the task" do
      expect{subject.schedule}.to change{Task.count}
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
  end

  context "given a saved task" do
    subject { super.save }

    let(now) { Time.utc(2016, 2, 15, 10, 20, 7) }

    describe ".destroy_old_tasks" do
      it "destroys old complete tasks" do
        subject.assign(complete: true, created_at: now).save
        expect{described_class.destroy_old_tasks}.to change{Task.count}.by(-1)
      end

      it "destroys old failed tasks" do
        subject.assign(backtrace: [""], created_at: now).save
        expect{described_class.destroy_old_tasks}.to change{Task.count}.by(-1)
      end

      it "ignores recent tasks" do
        subject.assign(complete: true, backtrace: [""]).save
        expect{described_class.destroy_old_tasks}.not_to change{Task.count}.from(1)
      end
    end

    describe ".clean_up_running_tasks" do
      it "sets running tasks to not running" do
        subject.assign(running: true).save
        expect{described_class.clean_up_running_tasks}.to change{Task.count(running: true)}.by(-1)
      end
    end
  end
end

Spectator.describe Task::ConcurrentTask do
  setup_spec

  class ConcurrentTask < ::Task
    include ::Task::ConcurrentTask

    def perform
      # no-op
    end
  end

  subject do
    ConcurrentTask.new(
      source_iri: "https://test.test/source",
      subject_iri: "https://test.test/subject"
    )
  end

  describe "#fiber_name" do
    subject { super.save }

    it "returns the name of the associated fiber" do
      expect(subject.fiber_name).to eq("#{subject.class}-#{subject.id}")
    end
  end
end
