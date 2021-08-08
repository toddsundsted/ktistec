require "../../src/controllers/settings"

require "../spec_helper/controller"

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

      context "and posting form data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"} }

        it "succeeds" do
          post "/settings/actor", headers, "name=&summary="
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings/actor", headers, "name=Foo+Bar&summary="
          expect(ActivityPub::Actor.find(actor.id).name).to eq("Foo Bar")
        end

        it "updates the summary" do
          post "/settings/actor", headers, "name=&summary=Foo+Bar"
          expect(ActivityPub::Actor.find(actor.id).summary).to eq("Foo Bar")
        end

        it "updates the image" do
          post "/settings/actor", headers, "image=%2Ffoo%2Fbar%2Fbaz"
          expect(ActivityPub::Actor.find(actor.id).image).to eq("https://test.test/foo/bar/baz")
        end

        it "updates the icon" do
          post "/settings/actor", headers, "icon=%2Ffoo%2Fbar%2Fbaz"
          expect(ActivityPub::Actor.find(actor.id).icon).to eq("https://test.test/foo/bar/baz")
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
          expect(ActivityPub::Actor.find(actor.id).name).to eq("Foo Bar")
        end

        it "updates the summary" do
          post "/settings/actor", headers, %q|{"name":"","summary":"Foo Bar"}|
          expect(ActivityPub::Actor.find(actor.id).summary).to eq("Foo Bar")
        end

        it "updates the image" do
          post "/settings/actor", headers, %q|{"image":"/foo/bar/baz"}|
          expect(ActivityPub::Actor.find(actor.id).image).to eq("https://test.test/foo/bar/baz")
        end

        it "updates the icon" do
          post "/settings/actor", headers, %q|{"icon":"/foo/bar/baz"}|
          expect(ActivityPub::Actor.find(actor.id).icon).to eq("https://test.test/foo/bar/baz")
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
