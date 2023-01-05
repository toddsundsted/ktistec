require "../../src/models/task"

require "../spec_helper/base"

Spectator.describe Task do
  setup_spec

  subject do
    described_class.new(
      source_iri: "https://test.test/source",
      subject_iri: "https://test.test/subject"
    )
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
    it "raises an error if the task is not runnable" do
      subject.running = true
      expect{subject.schedule}.to raise_error(Exception)
    end

    it "raises an error if the task is not runnable" do
      subject.complete = true
      expect{subject.schedule}.to raise_error(Exception)
    end

    it "raises an error if the task is not runnable" do
      subject.backtrace = [""]
      expect{subject.schedule}.to raise_error(Exception)
    end

    it "sets the next_attempt_at if specified" do
      time = 1.day.from_now
      expect{subject.schedule(time)}.to change{subject.next_attempt_at}
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
    create_task!(5)
    create_task!(6)
    create_task!(7)

    before_each do
      task6.assign(running: true).save
      task7.assign(complete: true).save
    end

    let(now) { Time.utc(2016, 2, 15, 10, 20, 7) }

    it "returns the scheduled tasks in priority order" do
      expect(described_class.scheduled(now)).to eq([task5, task4, task2, task3])
    end
  end
end
