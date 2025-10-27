require "../../src/controllers/uploads"

require "../spec_helper/controller"
require "../spec_helper/factory"

# redefine as public for testing
class UploadsController
  alias TestUpload = Upload

  def self.get_upload(env, path : String)
    previous_def(env, path)
  end

  def self.get_upload(env, p1 : String, p2 : String, p3 : String, id : String)
    previous_def(env, p1, p2, p3, id)
  end
end

Spectator.describe UploadsController do
  setup_spec

  let(current_actor_id) { Global.account.try(&.actor.id) }

  describe ".get_upload" do
    let(env) { env_factory("GET", "/") }

    let(actor1) { register.actor }
    let(actor2) { register.actor }

    context "with path string" do
      it "returns nil for valid path string" do
          result = UploadsController.get_upload(env, "/uploads/abc/def/ghi/#{actor1.id}.txt")
          expect(result).to be_nil
        end

      context "when authenticated" do
        sign_in(as: actor1.username)

        it "returns Upload instance" do
          result = UploadsController.get_upload(env, "/uploads/abc/def/ghi/#{actor1.id}.txt")
          expect(result).to be_a(UploadsController::TestUpload)
          expect(result.try(&.actor_id)).to eq(actor1.id)
        end

        it "returns nil for file owned by another user" do
          result = UploadsController.get_upload(env, "/uploads/abc/def/ghi/#{actor2.id}.txt")
          expect(result).to be_nil
        end

        it "returns nil for invalid path string" do
          result = UploadsController.get_upload(env, "/invalid/path/#{actor1.id}.txt")
          expect(result).to be_nil
        end

        it "returns nil for path traversal attempt" do
          result = UploadsController.get_upload(env, "/uploads/../../../etc/#{actor1.id}")
          expect(result).to be_nil
        end

        it "returns nil for malformed id" do
          result = UploadsController.get_upload(env, "/uploads/abc/def/ghi/not-a-number.txt")
          expect(result).to be_nil
        end
      end
    end

    context "with path components" do
      it "returns nil for valid path components" do
        result = UploadsController.get_upload(env, "abc", "def", "ghi", "#{actor1.id}.txt")
        expect(result).to be_nil
      end

      context "when authenticated" do
        sign_in(as: actor1.username)

        it "returns Upload instance" do
          result = UploadsController.get_upload(env, "abc", "def", "ghi", "#{actor1.id}.txt")
          expect(result).to be_a(UploadsController::TestUpload)
          expect(result.try(&.actor_id)).to eq(actor1.id)
        end

        it "returns nil for file owned by another user" do
          result = UploadsController.get_upload(env, "abc", "def", "ghi", "#{actor2.id}.txt")
          expect(result).to be_nil
        end

        it "returns nil for invalid path components" do
          result = UploadsController.get_upload(env, "abc!", "def", "ghi", "#{actor1.id}.txt")
          expect(result).to be_nil
        end

        it "returns nil for path traversal attempt" do
          result = UploadsController.get_upload(env, "uploads", "..", "etc", "#{actor1.id}.txt")
          expect(result).to be_nil
        end

        it "returns nil for malformed id" do
          result = UploadsController.get_upload(env, "abc", "def", "ghi", "not-a-number.txt")
          expect(result).to be_nil
        end
      end
    end
  end

  describe "POST /uploads" do
    it "returns 401 if not authorized" do
      post "/uploads"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      let(form) do
        String.build do |io|
          HTTP::FormData.build(io) do |form_data|
            metadata = HTTP::FormData::FileMetadata.new(filename: "digits.txt")
            form_data.file("file", IO::Memory.new("0123456789"), metadata)
          end
        end
      end

      let(headers) do
        HTTP::Headers{"Content-Type" => %Q{multipart/form-data; boundary="#{form.each_line.first[2..-1]}"}}
      end

      macro uploaded_file
        "#{Dir.tempdir}#{URI.parse(response.headers["Location"]).path}"
      end

      it "is successful" do
        post "/uploads", headers, form
        expect(response.status_code).to eq(201)
      end

      it "returns the resource URL in the location header" do
        post "/uploads", headers, form
        expect(response.headers["Location"]).to match(/\/uploads\/[a-z0-9\/]{18}\/#{current_actor_id}\.txt$/)
      end

      it "returns the resource path in the response" do
        post "/uploads", headers, form
        expect(JSON.parse(response.body)["msg"].as_s).to match(/\/uploads\/[a-z0-9\/]{18}\/#{current_actor_id}\.txt$/)
      end

      it "stores the file" do
        post "/uploads", headers, form
        expect(File.read_lines(uploaded_file).last).to eq("0123456789")
      end

      it "makes the file readable" do
        post "/uploads", headers, form
        expect(File.info(uploaded_file).permissions).to contain(File::Permissions[OtherRead, GroupRead, OwnerRead])
      end

      context "if file is not present" do
        let(form) do
          String.build do |io|
            HTTP::FormData.build(io) do |form_data|
              form_data.field("dummy", "dummy")
            end
          end
        end

        it "returns 400" do
          post "/uploads", headers, form
          expect(response.status_code).to eq(400)
        end
      end
    end
  end

  describe "DELETE /uploads/:p1/:p2/:p3/:id" do
    it "returns 401 if not authorized" do
      delete "/uploads/foo/bar/baz/0"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      let(path) { UUID.random.to_s.to_s.split("-")[0..2].join("/") }

      let(file) { "#{Dir.tempdir}/uploads/#{path}/#{current_actor_id}" }

      before_each do
        Dir.mkdir_p(Path[file].parent)
        File.open(file, "w") do |file|
          file << "0123456789"
        end
      end

      it "is successful" do
        delete "/uploads/#{path}/#{current_actor_id}"
        expect(response.status_code).to eq(200)
      end

      it "deletes the file" do
        delete "/uploads/#{path}/#{current_actor_id}"
        expect(File.exists?(file)).to be_false
      end

      it "returns 404 if the path contains invalid characters" do
        delete "/uploads/../../../#{current_actor_id}"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the upload does not belong to the user" do
        delete "/uploads/#{path}/0"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the upload does not exist" do
        delete "/uploads/foo/bar/baz/#{current_actor_id}"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "DELETE /uploads" do
    it "returns 401 if not authorized" do
      delete "/uploads"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      let(path) { UUID.random.to_s.to_s.split("-")[0..2].join("/") }

      let(file) { "#{Dir.tempdir}/uploads/#{path}/#{current_actor_id}" }

      before_each do
        Dir.mkdir_p(Path[file].parent)
        File.open(file, "w") do |file|
          file << "0123456789"
        end
      end

      it "is successful" do
        delete "/uploads", body: "/uploads/#{path}/#{current_actor_id}"
        expect(response.status_code).to eq(200)
      end

      it "deletes the file" do
        delete "/uploads", body: "/uploads/#{path}/#{current_actor_id}"
        expect(File.exists?(file)).to be_false
      end

      it "returns 404 if the path contains invalid characters" do
        delete "/uploads", body: "/uploads/../../../#{current_actor_id}"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the upload does not belong to the user" do
        delete "/uploads", body: "/uploads/#{path}/0"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the upload does not exist" do
        delete "/uploads", body: "/uploads/foo/bar/baz/#{current_actor_id}"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
