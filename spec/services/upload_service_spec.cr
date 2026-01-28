require "file_utils"

require "../../src/services/upload_service"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe UploadService do
  setup_spec

  let_create(:actor, named: :owner, local: true)

  let(temp_dir) { File.join(Dir.tempdir, "upload_service_test_#{Random.rand(10000)}") }

  before_each do
    Dir.mkdir_p(temp_dir)
  end

  after_each do
    FileUtils.rm_rf(temp_dir) if File.exists?(temp_dir)
  end

  describe ".upload" do
    let(filename) { "test.txt" }

    let(file_content) { "test content" }

    let(result) do
      tempfile = File.tempfile("upload_test")
      tempfile.print(file_content)
      tempfile.rewind
      UploadService.upload(tempfile, filename, owner.id!, public_folder: temp_dir, max_size: 1000_i64)
    end

    context "with temp file" do
      pre_condition { expect { result.valid? }.to be_true }

      it "generates valid file path" do
        expect(result.file_path).to match(/^\/uploads\/[a-z0-9-]+\/[a-z0-9-]+\/[a-z0-9-]+\/#{owner.id!}\.txt$/)
      end

      it "generates correct URI" do
        expect(result.file_uri).to eq("#{Ktistec.host}#{result.file_path}")
      end

      it "creates correct directory structure" do
        uploads_dir = File.join(temp_dir, "uploads")
        expect(File.exists?(uploads_dir)).to be_true
        expect(File.directory?(uploads_dir)).to be_true
      end

      it "moves file to correct location" do
        full_path = File.join(temp_dir, result.file_path.not_nil!)
        expect(File.exists?(full_path)).to be_true
        expect(File.read(full_path)).to eq(file_content)
      end

      it "sets correct file permissions" do
        full_path = File.join(temp_dir, result.file_path.not_nil!)
        file_info = File.info(full_path)
        expect(file_info.permissions.value & 0o777).to eq(0o644)
      end

      it "returns successful result" do
        expect(result.errors).to be_empty
      end
    end

    context "with empty file" do
      let(file_content) { "" }

      pre_condition { expect { result.valid? }.to be_false }

      it "returns error in result" do
        expect(result.errors["file"]?).not_to be_nil
        expect(result.errors["file"]).to have(/empty/)
      end

      it "does not create directories" do
        uploads_dir = File.join(temp_dir, "uploads")
        expect(File.exists?(uploads_dir)).to be_false
      end
    end

    context "with file exceeding max size" do
      let(file_content) { "x" * 10_000 }

      pre_condition { expect { result.valid? }.to be_false }

      it "returns error in result" do
        expect(result.errors["file"]?).not_to be_nil
        expect(result.errors["file"]).to have(/exceeds maximum/)
      end

      it "does not create directories" do
        uploads_dir = File.join(temp_dir, "uploads")
        expect(File.exists?(uploads_dir)).to be_false
      end
    end

    context "with file system error" do
      let(temp_dir) do
        File.join(Dir.tempdir, "upload_service_test_#{Random.rand(10000)}").tap do |dir|
          Dir.mkdir_p(dir)
          File.chmod(dir, 0o444)
        end
      end

      pre_condition { expect { result.valid? }.to be_false }

      it "returns error in result" do
        expect(result.errors["file"]?).not_to be_nil
        expect(result.errors["file"]).to have(/Failed to upload/)
      end

      it "does not create directories" do
        uploads_dir = File.join(temp_dir, "uploads")
        expect(File.exists?(uploads_dir)).to be_false
      end
    end
  end

  describe ".delete" do
    context "given a file" do
      let(test_file_path) do
        tempfile = File.tempfile("upload_test")
        tempfile.print("test content")
        tempfile.rewind
        result = UploadService.upload(tempfile, "test.txt", owner.id!, public_folder: temp_dir)
        result.file_path.not_nil!
      end

      pre_condition do
        full_path = File.join(temp_dir, test_file_path)
        expect(File.exists?(full_path)).to be_true
      end

      let(result) { UploadService.delete(test_file_path, owner.id!, public_folder: temp_dir) }

      pre_condition { expect(result.success?).to be_true }

      it "deletes the file" do
        full_path = File.join(temp_dir, test_file_path)
        expect(File.exists?(full_path)).to be_false
      end

      it "returns successful result" do
        expect(result.errors).to be_empty
      end

      it "includes deleted paths" do
        expect(result.deleted_paths).to have(/#{owner.id!}.txt/)
      end
    end

    context "when unauthorized" do
      let_create(:actor, named: :other, local: true)

      let(test_file_path) do
        tempfile = File.tempfile("upload_test")
        tempfile.print("test content")
        tempfile.rewind
        result = UploadService.upload(tempfile, "test.txt", other.id!, public_folder: temp_dir)
        result.file_path.not_nil!
      end

      pre_condition do
        full_path = File.join(temp_dir, test_file_path)
        expect(File.exists?(full_path)).to be_true
      end

      let(result) { UploadService.delete(test_file_path, owner.id!, public_folder: temp_dir) }

      pre_condition { expect(result.success?).to be_false }

      it "returns error in result" do
        expect(result.errors["file"]?).not_to be_nil
        expect(result.errors["file"]).to have(/does not belong/)
      end

      it "does not delete the file" do
        full_path = File.join(temp_dir, test_file_path)
        expect(File.exists?(full_path)).to be_true
      end
    end

    context "with non-existent file" do
      let(non_existent_path) { "/uploads/a/b/c/#{owner.id!}.txt" }

      let(result) { UploadService.delete(non_existent_path, owner.id!, public_folder: temp_dir) }

      pre_condition { expect(result.success?).to be_true }

      it "returns successful result" do
        expect(result.errors).to be_empty
      end
    end
  end

  describe ".authorize" do
    it "returns true" do
      path = "/uploads/a/b/c/#{owner.id!}.txt"

      expect(UploadService.authorize(path, owner.id!)).to be_true
    end

    it "returns false for invalid path" do
      path = "/invalid/path/format"

      expect(UploadService.authorize(path, owner.id!)).to be_false
    end

    context "with incorrect owner" do
      let_create(:actor, named: :other, local: true)

      it "returns false" do
        path = "/uploads/a/b/c/#{other.id!}.txt"

        expect(UploadService.authorize(path, owner.id!)).to be_false
      end
    end
  end

  describe "directory cleanup" do
    def file_write(dir, name, content = "test")
      File.join(dir, name).tap do |file_path|
        File.write(file_path, content)
      end
    end

    let(nested_dir) do
      File.join(temp_dir, "uploads", "a", "b", "c").tap do |nested_dir|
        Dir.mkdir_p(nested_dir)
      end
    end

    it "removes empty directories" do
      file_write(nested_dir, "#{owner.id!}.txt")

      path = "/uploads/a/b/c/#{owner.id!}.txt"
      result = UploadService.delete(path, owner.id!, public_folder: temp_dir)

      expect(result.success?).to be_true
      expect(Dir.exists?(nested_dir)).to be_false
      expect(Dir.exists?(File.dirname(nested_dir))).to be_false
      expect(Dir.exists?(File.dirname(File.dirname(nested_dir)))).to be_false
      expect(Dir.exists?(File.dirname(File.dirname(File.dirname(nested_dir))))).to be_true
    end

    it "does not remove non-empty directories" do
      file_write(nested_dir, "#{owner.id!}.txt")
      file_write(nested_dir, "#{owner.id!}.jpg")

      path = "/uploads/a/b/c/#{owner.id!}.txt"
      result = UploadService.delete(path, owner.id!, public_folder: temp_dir)

      expect(result.success?).to be_true
      expect(Dir.exists?(nested_dir)).to be_true
    end
  end
end
