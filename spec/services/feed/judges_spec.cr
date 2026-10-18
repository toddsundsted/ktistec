require "file_utils"

require "../../../src/services/feed/judges"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/feed/judges"

Spectator.describe Feed::Judges do
  setup_spec

  let(judges_dir) { File.tempname("ktistec", "judges") }

  around_each do |proc|
    directory = described_class.directory
    described_class.directory = judges_dir
    Dir.mkdir_p(judges_dir)
    begin
      proc.call
    ensure
      described_class.clear!
      described_class.directory = directory
      FileUtils.rm_rf(judges_dir)
    end
  end

  def write_judge(name, mode = 0o755)
    File.join(judges_dir, name).tap do |path|
      File.touch(path)
      File.chmod(path, mode)
    end
  end

  describe ".scan" do
    context "given an executable file" do
      let!(path) { write_judge("summarize") }

      it "registers the file as a judge" do
        described_class.scan
        expect(Feed::Backend.find?("summarize").as?(Feed::Backend::Executable).try(&.path)).to eq(path)
      end

      context "that is registered" do
        before_each { described_class.scan }

        pre_condition { expect(Feed::Backend.find?("summarize")).not_to be_nil }

        context "and is removed" do
          before_each { File.delete(path) }

          it "unregisters the judge" do
            described_class.scan
            expect(Feed::Backend.find?("summarize")).to be_nil
          end
        end

        context "and whose directory is removed" do
          before_each { FileUtils.rm_rf(judges_dir) }

          it "unregisters the judge" do
            described_class.scan
            expect(Feed::Backend.find?("summarize")).to be_nil
          end
        end
      end
    end

    context "given a file that isn't executable" do
      before_each { write_judge("summarize", 0o644) }

      it "does not register a judge" do
        described_class.scan
        expect(Feed::Backend.find?("summarize")).to be_nil
      end
    end

    context "given a subdirectory" do
      before_each { Dir.mkdir(File.join(judges_dir, "summarize")) }

      it "does not register a judge" do
        described_class.scan
        expect(Feed::Backend.find?("summarize")).to be_nil
      end
    end

    context "given a dotfile" do
      before_each { write_judge(".summarize") }

      it "does not register a judge" do
        described_class.scan
        expect(Feed::Backend.find?(".summarize")).to be_nil
      end
    end

    context "given a symlink to an executable file" do
      let(target) { File.tempname("ktistec", "judge") }

      before_each do
        File.touch(target)
        File.chmod(target, 0o755)
        File.symlink(target, File.join(judges_dir, "summarize"))
      end

      after_each { File.delete(target) }

      it "registers the symlink as a judge" do
        described_class.scan
        expect(Feed::Backend.find?("summarize")).to be_a(Feed::Backend::Executable)
      end
    end

    context "given a broken symlink" do
      before_each { File.symlink(File.tempname("ktistec", "judge"), File.join(judges_dir, "summarize")) }

      it "does not register a judge" do
        described_class.scan
        expect(Feed::Backend.find?("summarize")).to be_nil
      end
    end

    context "given an executable file with a built-in backend's name" do
      before_each { write_judge(Feed::Backend::Criteria::NAME) }

      it "does not replace the backend" do
        described_class.scan
        expect(Feed::Backend.find?(Feed::Backend::Criteria::NAME)).to be_a(Feed::Backend::Criteria)
      end

      context "that is removed" do
        before_each do
          described_class.scan
          File.delete(File.join(judges_dir, Feed::Backend::Criteria::NAME))
        end

        it "does not unregister the backend" do
          described_class.scan
          expect(Feed::Backend.find?(Feed::Backend::Criteria::NAME)).to be_a(Feed::Backend::Criteria)
        end
      end
    end
  end
end
