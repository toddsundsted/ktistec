require "../../../src/models/task/performance"

require "../../spec_helper/base"

Spectator.describe Task::Performance do
  setup_spec

  describe ".schedule_unless_exists" do
    it "schedules a new task" do
      expect{described_class.schedule_unless_exists}.to change{described_class.count}.by(1)
    end

    context "given an existing task" do
      before_each { described_class.new.schedule }

      it "does not schedule a new task" do
        expect{described_class.schedule_unless_exists}.not_to change{described_class.count}
      end
    end
  end

  describe "#perform" do
    subject { described_class.new }

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end

    it "records three data points" do
      expect{subject.perform}.to change{Point.count}.by(4)
    end
  end
end
