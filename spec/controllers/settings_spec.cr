require "../../src/controllers/settings"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe SettingsController do
  setup_spec

  let(actor) { register.actor }

  describe "GET /settings" do
    it "returns 401 if not authorized" do
      get "/settings"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      context "and accepting HTML" do
        let(headers) { HTTP::Headers{"Accept" => "text/html"} }

        it "succeeds" do
          get "/settings", headers
          expect(response.status_code).to eq(200)
        end

        it "renders a form" do
          get "/settings", headers
          expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='name']][.//input[@name='summary']][.//input[@name='image']][.//input[@name='icon']]")).not_to be_empty
        end

        it "renders a form" do
          get "/settings", headers
          expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='footer']][.//input[@name='site']]")).not_to be_empty
        end

        before_each do
          ENV.delete("DEEPL_API_KEY")
          ENV.delete("LIBRETRANSLATE_API_KEY")
        end
        after_each do
          ENV.delete("DEEPL_API_KEY")
          ENV.delete("LIBRETRANSLATE_API_KEY")
        end

        it "does not render an option for the translator service" do
          get "/settings", headers
          expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_service']]//input[@type='radio']")).to be_empty
        end

        it "does not render an input for the service URL" do
          get "/settings", headers
          expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_url']]//input[@type='text']")).to be_empty
        end

        context "given an API key for the DeepL service" do
          before_each { ENV["DEEPL_API_KEY"] = "API_KEY" }
          after_each { ENV.delete("DEEPL_API_KEY") }

          it "renders an option for the DeepL service" do
            get "/settings", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_service']]//input[@type='radio']/@value")).to have("deepl")
          end

          it "does not render an option for the LibreTranslate service" do
            get "/settings", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_service']]//input[@type='radio']/@value")).not_to have("libretranslate")
          end

          it "renders an input for the service URL" do
            get "/settings", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_url']]//input[@type='text']")).not_to be_empty
          end
        end

        context "given an API key for the LibreTranslate service" do
          before_each { ENV["LIBRETRANSLATE_API_KEY"] = "API_KEY" }
          after_each { ENV.delete("LIBRETRANSLATE_API_KEY") }

          it "renders an option for the LibreTranslate service" do
            get "/settings", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_service']]//input[@type='radio']/@value")).to have("libretranslate")
          end

          it "does not render an option for the DeepL service" do
            get "/settings", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_service']]//input[@type='radio']/@value")).not_to have("deepl")
          end

          it "renders an input for the service URL" do
            get "/settings", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='translator_url']]//input[@type='text']")).not_to be_empty
          end
        end
      end

      context "and accepting JSON" do
        let(headers) { HTTP::Headers.new }

        it "succeeds" do
          get "/settings", headers
          expect(response.status_code).to eq(200)
        end

        it "renders an object" do
          get "/settings", headers
          expect(JSON.parse(response.body).as_h.keys).to have("name", "summary", "image", "icon", "footer", "site")
        end
      end
    end
  end

  describe "POST /settings/actor" do
    it "returns 401 if not authorized" do
      post "/settings/actor"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      let(account) { Global.account.not_nil! }

      context "and posting urlencoded data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"} }

        let(query_string) {
          [
            "name=Foo+Bar",
            "summary=Blah+Blah",
            "password=foobarbaz1%21",
            "language=fr",
            "timezone=Etc%2FGMT",
            "image=%2Ffoo%2Fbar%2Fbaz",
            "icon=%2Ffoo%2Fbar%2Fbaz",
          ].join("&")
        }

        it "succeeds" do
          post "/settings/actor", headers, query_string
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings/actor", headers, "name=Foo+Bar"
          expect(actor.reload!.name).to eq("Foo Bar")
        end

        context "given an actor with a name" do
          before_each { actor.assign(name: "Foo Bar").save }

          it "updates the name if blank" do
            expect{post "/settings/actor", headers, "name="}.
              to change{actor.reload!.name}.from("Foo Bar").to("")
          end
        end

        it "updates the summary" do
          post "/settings/actor", headers, "summary=Blah+Blah"
          expect(actor.reload!.summary).to eq("Blah Blah")
        end

        it "updates the language" do
          post "/settings/actor", headers, "language=fr"
          expect(account.reload!.language).to eq("fr")
        end

        context "given an account with a language" do
          before_each { account.assign(language: "en").save }

          it "does not update the language if blank" do
            expect{post "/settings/actor", headers, "language="}.
              not_to change{account.reload!.language}
          end
        end

        it "updates the timezone" do
          post "/settings/actor", headers, "timezone=Etc%2FGMT"
          expect(account.reload!.timezone).to eq("Etc/GMT")
        end

        context "given an account with a timezone" do
          before_each { account.assign(timezone: "America/New_York").save }

          it "does not update the timezone if blank" do
            expect{post "/settings/actor", headers, "timezone="}.
              not_to change{account.reload!.timezone}
          end
        end

        it "updates the password" do
          expect{post "/settings/actor", headers, "password=foobarbaz1%21"}.
            to change{account.reload!.encrypted_password}
        end

        it "does not update the password if blank" do
          expect{post "/settings/actor", headers, "password="}.
            not_to change{account.reload!.encrypted_password}
        end

        it "does not update the password if empty" do
          expect{post "/settings/actor", headers, "password=%20"}.
            not_to change{account.reload!.encrypted_password}
        end

        it "updates the image" do
          post "/settings/actor", headers, "image=%2Ffoo%2Fbar%2Fbaz"
          expect(actor.reload!.image).to eq("https://test.test/foo/bar/baz")
        end

        it "updates the icon" do
          post "/settings/actor", headers, "icon=%2Ffoo%2Fbar%2Fbaz"
          expect(actor.reload!.icon).to eq("https://test.test/foo/bar/baz")
        end

        context "given an actor with an image and an icon" do
          before_each { actor.assign(image: "https://test.test/foo/bar/baz", icon: "https://test.test/foo/bar/baz").save }

          it "removes the image" do
            post "/settings/actor", headers, "image="
            expect(actor.reload!.image).to be_nil
          end

          it "removes the icon" do
            post "/settings/actor", headers, "icon="
            expect(actor.reload!.icon).to be_nil
          end
        end

        it "updates the attachments" do
          post "/settings/actor", headers, "attachment_0_name=Blog&attachment_0_value=https://beowulf.example.com"
          attachments = actor.reload!.attachments.not_nil!
          expect(attachments.size).to eq(1)
          expect(attachments.first.name).to eq("Blog")
          expect(attachments.first.value).to eq("https://beowulf.example.com")
        end
      end

      context "and posting form data" do
        let(form) do
          String.build do |io|
            HTTP::FormData.build(io) do |form_data|
              metadata = HTTP::FormData::FileMetadata.new(filename: "image.jpg")
              form_data.file("image", IO::Memory.new("0123456789"), metadata)
              metadata = HTTP::FormData::FileMetadata.new(filename: "icon.jpg")
              form_data.file("icon", IO::Memory.new("0123456789"), metadata)
            end
          end
        end

        let(headers) do
          HTTP::Headers{"Content-Type" => %Q{multipart/form-data; boundary="#{form.lines.first[2..-1]}"}}
        end

        macro uploaded_image(actor)
          "#{Dir.tempdir}#{URI.parse({{actor}}.reload!.image.not_nil!).path}"
        end

        it "updates the image" do
          expect{post "/settings/actor", headers, form}.to change{actor.reload!.image}.from(nil)
        end

        it "updates the icon" do
          expect{post "/settings/actor", headers, form}.to change{actor.reload!.icon}.from(nil)
        end

        it "stores the image file" do
          post "/settings/actor", headers, form
          expect(File.exists?(uploaded_image(actor))).to be(true)
        end

        it "makes the image file readable" do
          post "/settings/actor", headers, form
          expect(File.info(uploaded_image(actor)).permissions).to contain(File::Permissions[OtherRead, GroupRead, OwnerRead])
        end

        it "stores the icon file" do
          post "/settings/actor", headers, form
          expect(File.exists?(uploaded_image(actor))).to be(true)
        end

        it "makes the icon file readable" do
          post "/settings/actor", headers, form
          expect(File.info(uploaded_image(actor)).permissions).to contain(File::Permissions[OtherRead, GroupRead, OwnerRead])
        end

        context "given existing image and icon" do
          before_each do
            actor.assign(image: "https://test.test/foo/bar.jpg", icon: "https://test.test/foo/bar.jpg").save
          end

          it "updates the image" do
            expect{post "/settings/actor", headers, form}.to change{actor.reload!.image}.from("https://test.test/foo/bar.jpg")
          end

          it "updates the icon" do
            expect{post "/settings/actor", headers, form}.to change{actor.reload!.icon}.from("https://test.test/foo/bar.jpg")
          end
        end
      end

      context "and posting JSON data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

        let(json_string) {
          {
            name: "Foo Bar",
            summary: "Blah Blah",
            password: "foobarbaz1!",
            language: "fr",
            timezone: "Etc/GMT",
            image: "/foo/bar/baz",
            icon: "/foo/bar/baz",
          }.to_json
        }

        it "succeeds" do
          post "/settings/actor", headers, json_string
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings/actor", headers, %q|{"name":"Foo Bar"}|
          expect(actor.reload!.name).to eq("Foo Bar")
        end

        context "given an actor with a name" do
          before_each { actor.assign(name: "Foo Bar").save }

          it "updates the name if blank" do
            expect{post "/settings/actor", headers, %q|{"name":""}|}.
              to change{actor.reload!.name}.from("Foo Bar").to("")
          end
        end

        it "updates the summary" do
          post "/settings/actor", headers, %q|{"summary":"Blah Blah"}|
          expect(actor.reload!.summary).to eq("Blah Blah")
        end

        it "updates the language" do
          post "/settings/actor", headers, %q|{"language":"fr"}|
          expect(account.reload!.language).to eq("fr")
        end

        context "given an account with a language" do
          before_each { account.assign(language: "en").save }

          it "does not update the language if blank" do
            expect{post "/settings/actor", headers, %q|{"language":""}|}.
              not_to change{account.reload!.language}
          end
        end

        it "updates the timezone" do
          post "/settings/actor", headers, %q|{"name":"","summary":"","timezone":"Etc/GMT"}|
          expect(account.reload!.timezone).to eq("Etc/GMT")
        end

        context "given an account with a timezone" do
          before_each { account.assign(timezone: "America/New_York").save }

          it "does not update the timezone if blank" do
            expect{post "/settings/actor", headers, %q|{"timezone":""}|}.
              not_to change{account.reload!.timezone}
          end
        end

        it "updates the password" do
          expect{post "/settings/actor", headers, %q|{"password":"foobarbaz1!"}|}.
            to change{account.reload!.encrypted_password}
        end

        it "does not update the password if blank" do
          expect{post "/settings/actor", headers, %q|{"password":""}|}.
            not_to change{account.reload!.encrypted_password}
        end

        it "does not update the password if null" do
          expect{post "/settings/actor", headers, %q|{"password":null}|}.
            not_to change{account.reload!.encrypted_password}
        end

        it "updates the image" do
          post "/settings/actor", headers, %q|{"image":"/foo/bar/baz"}|
          expect(actor.reload!.image).to eq("https://test.test/foo/bar/baz")
        end

        it "updates the icon" do
          post "/settings/actor", headers, %q|{"icon":"/foo/bar/baz"}|
          expect(actor.reload!.icon).to eq("https://test.test/foo/bar/baz")
        end

        context "given an actor with an image and an icon" do
          before_each { actor.assign(image: "https://test.test/foo/bar/baz", icon: "https://test.test/foo/bar/baz").save }

          it "removes the image" do
            post "/settings/actor", headers, %q|{"image":null}|
            expect(actor.reload!.image).to be_nil
          end

          it "removes the icon" do
            post "/settings/actor", headers, %q|{"icon":null}|
            expect(actor.reload!.icon).to be_nil
          end
        end

        it "updates the attachments" do
          post "/settings/actor", headers, %q|{"attachment_0_name":"Blog","attachment_0_value":"https://beowulf.example.com"}|
          attachments = actor.reload!.attachments.not_nil!
          expect(attachments.size).to eq(1)
          expect(attachments.first.name).to eq("Blog")
          expect(attachments.first.value).to eq("https://beowulf.example.com")
        end
      end
    end
  end

  describe "POST /settings/service" do
    it "returns 401 if not authorized" do
      post "/settings/service"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      after_each do
        Ktistec.set_default_settings
      end

      context "and posting urlencoded data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"} }

        let(query_string) { "host=https%3A%2F%2Ffoo.bar%2F&site=Name&footer=Copyright+Blah+Blah" }

        it "succeeds" do
          post "/settings/service", headers, query_string
          expect(response.status_code).to eq(302)
        end

        it "does not change the host" do
          expect {post "/settings/service", headers, "host=https%3A%2F%2Ffoo.bar%2F"}.
            not_to change{Ktistec.settings.host}
        end

        it "changes the site" do
          expect {post "/settings/service", headers, "site=Name"}.
            to change{Ktistec.settings.site}
        end

        it "does not change the site" do
          expect {post "/settings/service", headers, "site="}.
            not_to change{Ktistec.settings.site}
        end

        it "changes the footer" do
          expect {post "/settings/service", headers, "footer=Copyright+Blah+Blah"}.
            to change{Ktistec.settings.footer}
        end

        context "given a footer" do
          before_each { Ktistec.settings.assign({"footer" => "Copyright Blah Blah"}).save }

          it "changes the footer if blank" do
            expect {post "/settings/service", headers, "footer="}.
              to change{Ktistec.settings.footer}.from("Copyright Blah Blah").to("")
          end
        end
      end

      context "and posting JSON data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

        let(json_string) { {"host" => "https://foo.bar/", "site" => "Name", "footer" => "Copyright Blah Blah"}.to_json }

        it "succeeds" do
          post "/settings/service", headers, json_string
          expect(response.status_code).to eq(302)
        end

        it "does not change the host" do
           expect {post "/settings/service", headers, %q|{"host":"https://foo.bar/"}|}.
            not_to change{Ktistec.settings.host}
        end

        it "changes the site" do
          expect {post "/settings/service", headers, %q|{"site":"Name"}|}.
            to change{Ktistec.settings.site}
        end

        it "does not change the site" do
          expect {post "/settings/service", headers, %q|{"site":""}|}.
            not_to change{Ktistec.settings.site}
        end

        it "changes the footer" do
          expect {post "/settings/service", headers, %q|{"footer":"Copyright Blah Blah"}|}.
            to change{Ktistec.settings.footer}
        end

        context "given a footer" do
          before_each { Ktistec.settings.assign({"footer" => "Copyright Blah Blah"}).save }

          it "changes the footer if blank" do
            expect {post "/settings/service", headers, %q|{"footer":""}|}.
              to change{Ktistec.settings.footer}.from("Copyright Blah Blah").to("")
          end
        end
      end
    end
  end

  describe "POST /settings/terminate" do
    it "returns 401 if not authorized" do
      post "/settings/terminate"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "schedules a terminate task" do
        expect{post "/settings/terminate"}.to change{Task::Terminate.count(subject_iri: actor.iri, source_iri: actor.iri)}.by(1)
      end

      it "destroys the account" do
        expect{post "/settings/terminate"}.to change{Account.count}.by(-1)
      end

      it "ends the session" do
        expect{post "/settings/terminate"}.to change{Session.count}.by(-1)
      end

      it "redirects" do
        post "/settings/terminate"
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end
    end
  end
end
