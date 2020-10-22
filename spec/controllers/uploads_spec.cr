require "../spec_helper"

Spectator.describe UploadsController do
  setup_spec

  around_each do |example|
    previous, Kemal.config.public_folder = Kemal.config.public_folder, Dir.tempdir
    example.call
  ensure
    Kemal.config.public_folder = previous if previous
  end

  let(current_actor_id) { Global.account.try(&.actor.id) }

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

      it "returns 400 if the path contains invalid characters" do
        delete "/uploads/../../../#{current_actor_id}"
        expect(response.status_code).to eq(400)
      end

      it "returns 403 if the upload does not belong to the user" do
        delete "/uploads/#{path}/0"
        expect(response.status_code).to eq(403)
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

      it "returns 400 if the path contains invalid characters" do
        delete "/uploads", body: "/uploads/../../../#{current_actor_id}"
        expect(response.status_code).to eq(400)
      end

      it "returns 403 if the upload does not belong to the user" do
        delete "/uploads", body: "/uploads/#{path}/0"
        expect(response.status_code).to eq(403)
      end

      it "returns 404 if the upload does not exist" do
        delete "/uploads", body: "/uploads/foo/bar/baz/#{current_actor_id}"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
