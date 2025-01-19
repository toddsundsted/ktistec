require "../../../src/models/task/run_scripts"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::RunScripts do
  setup_spec

  let!(account) { register }

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

    it "cleans up its session" do
      expect{subject.perform}.not_to change{account.reload!.sessions}
    end

    context "if there is no account yet" do
      before_each { account.destroy }

      it "does not raise an error" do
        expect{subject.perform}.not_to raise_error
      end

      it "sets the next attempt at" do
        subject.perform
        expect(subject.next_attempt_at).not_to be_nil
      end
    end
  end
end
