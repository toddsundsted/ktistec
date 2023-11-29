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

      context "and posting form data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"} }

        it "succeeds" do
          post "/settings/actor", headers, "name=&summary=&password="
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings/actor", headers, "name=Foo+Bar&summary="
          expect(actor.reload!.name).to eq("Foo Bar")
        end

        it "updates the summary" do
          post "/settings/actor", headers, "name=&summary=Foo+Bar"
          expect(actor.reload!.summary).to eq("Foo Bar")
        end

        it "updates the timezone" do
          post "/settings/actor", headers, "name=&summary=&timezone=Etc/GMT"
          expect(account.reload!.timezone).to eq("Etc/GMT")
        end

        context "given an account with a timezone" do
          before_each { account.assign(timezone: "Etc/UTC").save }

          it "does not updates the timezone if blank" do
            expect{post "/settings/actor", headers, "timezone="}.
              not_to change{account.reload!.timezone}
          end
        end

        it "updates the password" do
          expect{post "/settings/actor", headers, "password=foobarbaz1!"}.
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

      context "and posting JSON data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

        it "succeeds" do
          post "/settings/actor", headers, %q|{"name":"","summary":""}|
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings/actor", headers, %q|{"name":"Foo Bar","summary":""}|
          expect(actor.reload!.name).to eq("Foo Bar")
        end

        it "updates the summary" do
          post "/settings/actor", headers, %q|{"name":"","summary":"Foo Bar"}|
          expect(actor.reload!.summary).to eq("Foo Bar")
        end

        it "updates the timezone" do
          post "/settings/actor", headers, %q|{"name":"","summary":"","timezone":"Etc/GMT"}|
          expect(account.reload!.timezone).to eq("Etc/GMT")
        end

        context "given an account with a timezone" do
          before_each { account.assign(timezone: "Etc/UTC").save }

          it "does not updates the timezone if blank" do
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
        Ktistec.settings.clear_footer
        Ktistec.settings.site = "Test"
      end

      context "and posting form data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"} }

        it "succeeds" do
          post "/settings/service", headers, "site=Name&footer="
          expect(response.status_code).to eq(302)
        end

        it "changes the footer" do
          expect {post "/settings/service", headers, "site=Name&footer=Copyright Blah Blah"}.
            to change{Ktistec.settings.footer}
        end

        it "changes the site" do
          expect {post "/settings/service", headers, "site=Name"}.
            to change{Ktistec.settings.site}
        end

        it "does not change the site" do
          expect {post "/settings/service", headers, "site="}.
            not_to change{Ktistec.settings.site}
        end
      end

      context "and posting JSON data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

        it "succeeds" do
          post "/settings/service", headers, %q|{"site":"Name","footer":""}|
          expect(response.status_code).to eq(302)
        end

        it "changes the footer" do
          expect {post "/settings/service", headers, %q|{"site":"Name","footer":"Copyright Blah Blah"}|}.
            to change{Ktistec.settings.footer}
        end

        it "changes the site" do
          expect {post "/settings/service", headers, %q|{"site":"Name"}|}.
            to change{Ktistec.settings.site}
        end

        it "does not change the site" do
          expect {post "/settings/service", headers, %q|{"site":""}|}.
            not_to change{Ktistec.settings.site}
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
