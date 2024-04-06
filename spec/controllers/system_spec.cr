require "../../src/controllers/system"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe SystemController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}

  let(actor) { register.actor }

  describe "GET /system" do
    it "returns 401 if not authorized" do
      get "/system"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        get "/system"
        expect(response.status_code).to eq(200)
      end

      context "given a source of logs" do
        before_each { ::Log.for("foo.bar").trace { "test" } }

        it "renders an input" do
          get "/system", HTML_HEADERS
          expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='foo.bar']")).not_to be_empty
        end

        it "renders an object" do
          get "/system", JSON_HEADERS
          expect(JSON.parse(response.body).dig?("logLevels", "foo.bar")).not_to be_nil
        end

        context "and a log level" do
          before_each { Ktistec::LogLevel.new("foo.bar", :info).save }

          it "renders the log level" do
            get "/system", HTML_HEADERS
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@checked][@name='foo.bar']/@value").first).to eq("Info")
          end

          it "renders the log level" do
            get "/system", JSON_HEADERS
            expect(JSON.parse(response.body).dig?("logLevels", "foo.bar", "severity")).to eq("Info")
          end
        end
      end
    end
  end

  describe "POST /system" do
    it "returns 401 if not authorized" do
      post "/system"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "redirects" do
        post "/system"
        expect(response.status_code).to eq(302)
      end

      context "given a source of logs" do
        before_each { ::Log.for("foo.bar").trace { "test" } }

        it "sets the log level" do
          post "/system", HTML_HEADERS, "foo.bar=Info"
          expect(Ktistec::LogLevel.all_as_hash["foo.bar"].severity).to eq(::Log::Severity::Info)
        end

        it "sets the log level" do
          post "/system", JSON_HEADERS, %q|{"logLevels":{"foo.bar":"Info"}}|
          expect(Ktistec::LogLevel.all_as_hash["foo.bar"].severity).to eq(::Log::Severity::Info)
        end

        context "and a log level" do
          before_each { Ktistec::LogLevel.new("foo.bar", :info).save }

          it "resets the log level" do
            post "/system", HTML_HEADERS, "foo.bar="
            expect(Ktistec::LogLevel.all_as_hash).not_to have_key("foo.bar")
          end

          it "resets the log level" do
            post "/system", JSON_HEADERS, %q|{"logLevels":{"foo.bar":null}}|
            expect(Ktistec::LogLevel.all_as_hash).not_to have_key("foo.bar")
          end
        end
      end
    end
  end
end
