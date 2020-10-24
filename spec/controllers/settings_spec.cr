require "../spec_helper"

Spectator.describe SettingsController do
  setup_spec

  describe "GET /settings" do
    it "returns 401 if not authorized" do
      get "/settings"
      expect(response.status_code).to eq(401)
    end

    let(actor) { register.actor }

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
      end

      context "and accepting JSON" do
        let(headers) { HTTP::Headers.new }

        it "succeeds" do
          get "/settings", headers
          expect(response.status_code).to eq(200)
        end

        it "renders a form" do
          get "/settings", headers
          expect(JSON.parse(response.body).as_h.keys).to have("name", "summary", "image", "icon")
        end
      end
    end
  end

  describe "POST /settings" do
    it "returns 401 if not authorized" do
      post "/settings"
      expect(response.status_code).to eq(401)
    end

    let(actor) { register.actor }

    context "when authorized" do
      sign_in(as: actor.username)

      context "and receiving form data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"} }

        it "succeeds" do
          post "/settings", headers, "name=&summary="
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings", headers, "name=Foo+Bar&summary="
          expect(ActivityPub::Actor.find(actor.id).name).to eq("Foo Bar")
        end

        it "updates the summary" do
          post "/settings", headers, "name=&summary=Foo+Bar"
          expect(ActivityPub::Actor.find(actor.id).summary).to eq("Foo Bar")
        end
      end

      context "and receiving JSON data" do
        let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

        it "succeeds" do
          post "/settings", headers, %q|{"name":"","summary":""}|
          expect(response.status_code).to eq(302)
        end

        it "updates the name" do
          post "/settings", headers, %q|{"name":"Foo Bar","summary":""}|
          expect(ActivityPub::Actor.find(actor.id).name).to eq("Foo Bar")
        end

        it "updates the summary" do
          post "/settings", headers, %q|{"name":"","summary":"Foo Bar"}|
          expect(ActivityPub::Actor.find(actor.id).summary).to eq("Foo Bar")
        end
      end
    end
  end
end
