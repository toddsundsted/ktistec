require "file_utils"

require "../../src/framework/assets"

require "../spec_helper/base"

Spectator.describe Ktistec::Assets do
  let(tmp_dir) { File.join(Dir.tempdir, "assets_#{Random.new.rand(10000)}") }

  let(file_path) { File.join(tmp_dir, "dist", "site.css") }

  around_each do |example|
    Dir.mkdir_p(File.join(tmp_dir, "dist"))
    public_folder = Kemal.config.public_folder
    Kemal.config.public_folder = tmp_dir
    begin
      example.call
    ensure
      Kemal.config.public_folder = public_folder
      FileUtils.rm_rf(tmp_dir)
    end
  end

  describe ".digest?" do
    subject { described_class.digest?("/dist/site.css") }

    it "returns nil" do
      expect(subject).to be_nil
    end

    context "given a directory" do
      before_each { Dir.mkdir_p(file_path) }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given a path traversal" do
      before_each { File.write(File.join(tmp_dir, "secret.txt"), "secret") }

      it "returns nil" do
        expect(described_class.digest?("/dist/../secret.txt")).to be_nil
      end
    end

    context "given an asset" do
      before_each { File.write(file_path, "body {}") }

      it "returns a digest" do
        expect(subject).to match(/^[0-9a-f]{8}$/)
      end

      it "returns the same digest" do
        expect(subject).to eq(described_class.digest?("/dist/site.css"))
      end

      context "and the asset is not readable" do
        before_each { File.chmod(file_path, 0o000) }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "and the asset is rewritten with new contents" do
        before_each do
          subject
          File.write(file_path, "body { color: red }")
          File.touch(file_path, Time.utc + 1.second)
        end

        it "returns a new digest" do
          expect(described_class.digest?("/dist/site.css")).not_to eq(subject)
        end
      end

      context "and the asset is rewritten with the same contents" do
        before_each do
          subject
          File.write(file_path, "body {}")
          File.touch(file_path, Time.utc + 1.second)
        end

        it "returns the same digest" do
          expect(described_class.digest?("/dist/site.css")).to eq(subject)
        end
      end
    end
  end
end
