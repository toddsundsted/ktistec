require "file_utils"

require "../../../../src/models/task/feed/discover_judges"

require "../../../spec_helper/base"
require "../../../spec_helper/feed/judges"

Spectator.describe Task::Feed::DiscoverJudges do
  setup_spec

  describe "#perform" do
    let(judges_dir) { File.tempname("ktistec", "judges") }

    around_each do |proc|
      directory = ::Feed::Judges.directory
      ::Feed::Judges.directory = judges_dir
      Dir.mkdir_p(judges_dir)
      begin
        proc.call
      ensure
        ::Feed::Judges.clear!
        ::Feed::Judges.directory = directory
        FileUtils.rm_rf(judges_dir)
      end
    end

    context "given an executable file in the judges directory" do
      before_each do
        path = File.join(judges_dir, "summarize")
        File.touch(path)
        File.chmod(path, 0o755)
      end

      it "registers the file as a judge" do
        subject.perform
        expect(::Feed::Backend.find?("summarize")).not_to be_nil
      end
    end

    it "reschedules itself" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end
  end
end
