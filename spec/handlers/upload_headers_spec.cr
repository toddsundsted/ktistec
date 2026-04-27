require "uuid"

require "../../src/handlers/upload_headers"
require "../../src/framework/controller"

require "../spec_helper/factory"
require "../spec_helper/controller"

class UploadHeadersFooBarController
  include Ktistec::Controller

  skip_auth ["/foo/bar/passthrough"], GET

  get "/foo/bar/passthrough" do
  end
end

Spectator.describe Ktistec::Handler::UploadHeaders do
  setup_spec

  describe "GET /uploads/..." do
    let(upload_dir) { File.join(Kemal.config.public_folder, "uploads", "test-#{UUID.random}") }
    let(upload_path) { File.join(upload_dir, "1.png") }
    let(request_path) { upload_path.sub(Kemal.config.public_folder, "") }

    around_each do |example|
      Dir.mkdir_p(upload_dir)
      File.write(upload_path, "not really a png")
      begin
        example.call
      ensure
        File.delete(upload_path) if File.exists?(upload_path)
        Dir.delete(upload_dir) if Dir.exists?(upload_dir)
      end
    end

    it "sets X-Content-Type-Options to nosniff" do
      get request_path
      expect(response.headers["X-Content-Type-Options"]?).to eq("nosniff")
    end
  end

  describe "GET /foo/bar/passthrough" do
    it "does not set X-Content-Type-Options" do
      get "/foo/bar/passthrough"
      expect(response.headers["X-Content-Type-Options"]?).to be_nil
    end
  end
end
