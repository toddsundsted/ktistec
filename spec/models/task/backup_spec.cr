require "../../../src/models/task/backup"

require "../../spec_helper/base"

Spectator.describe Task::Backup do
  setup_spec

  describe ".ensure_scheduled" do
    it "schedules a new task" do
      expect{described_class.ensure_scheduled}.to change{described_class.count}.by(1)
    end

    context "given an existing task" do
      before_each { described_class.new.schedule }

      it "does not schedule a new task" do
        expect{described_class.ensure_scheduled}.not_to change{described_class.count}
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

  describe "#perform_backup" do
    subject { described_class.new }

    let(name) { Ktistec.db_file }
    let(date) { Time.local.to_s("%Y%m%d") }
    let(backup) { "#{name}.backup_#{date}" }

    it "dumps a backup file" do
      subject.perform_backup
      expect(File.exists?(backup))
    end
  end
end
