require "../../../src/models/task/backup"

require "../../spec_helper/model"

Spectator.describe Task::Backup do
  setup_spec

  describe ".schedule_unless_exists" do
    it "schedules a new task" do
      expect{described_class.schedule_unless_exists}.to change{Task::Backup.count}.by(1)
    end

    context "given an existing task" do
      before_each { described_class.new.schedule }

      it "does not schedule a new task" do
        expect{described_class.schedule_unless_exists}.not_to change{Task::Backup.count}
      end
    end
  end

  describe "#perform_backup" do
    subject { described_class.new }

    it "sets the next attempt at" do
      subject.perform_backup
      expect(subject.next_attempt_at).not_to be_nil
    end

    let(file) { Ktistec.db_file }
    let(date) { Time.local.to_s("%Y%m%d") }
    let(backup) { "#{file}.backup_#{date}".split("//").last }

    it "dumps a backup file" do
      subject.perform_backup
      expect(File.exists?(backup))
    end
  end
end
