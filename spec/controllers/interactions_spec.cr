require "../../src/controllers/interactions"

require "../spec_helper/factory"
require "../spec_helper/network"
require "../spec_helper/controller"

Spectator.describe InteractionsController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}

  let(actor) { register.actor.assign(name: "Actor").save }

  let_create(object, attributed_to: actor)

  describe "GET /objects/:id/remote-foobar" do
    it "returns 404" do
      get "/objects/#{object.iri.split('/').last}/remote-foobar"
      expect(response.status_code).to eq(404)
    end
  end

  describe "GET /objects/:id/remote-reply" do
    it "returns 404 if not found" do
      get "/objects/missing/remote-reply"
      expect(response.status_code).to eq(404)
    end

    it "succeeds" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", HTML_HEADERS
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", JSON_HEADERS
      expect(response.status_code).to eq(200)
    end

    it "renders a form" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='domain']]")).not_to be_empty
    end

    it "returns a template" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", JSON_HEADERS
      expect(JSON.parse(response.body).dig?("domain")).not_to be_nil
    end

    it "includes the target" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='target']/@value").first).to eq(object.iri)
    end

    it "includes the target" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", JSON_HEADERS
      expect(JSON.parse(response.body).dig?("target")).to eq(object.iri)
    end

    it "includes the action" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='action']/@value").first).to eq("reply")
    end

    it "includes the action" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", JSON_HEADERS
      expect(JSON.parse(response.body).dig?("action")).to eq("reply")
    end

    it "renders the message" do
      get "/objects/#{object.iri.split('/').last}/remote-reply", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//h1").first).to match(/Reply to Actor's post/)
    end
  end

  # currently, the actions for the following two sets of specs differ
  # only in how they generate the message.

  describe "GET /objects/:id/remote-like" do
    it "renders the message" do
      get "/objects/#{object.iri.split('/').last}/remote-like", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//h1").first).to match(/Like Actor's post/)
    end
  end

  describe "GET /objects/:id/remote-share" do
    it "renders the message" do
      get "/objects/#{object.iri.split('/').last}/remote-share", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//h1").first).to match(/Share Actor's post/)
    end
  end

  describe "GET /actors/:username/remote-follow" do
    it "returns 404 if not found" do
      get "/actors/missing/remote-follow"
      expect(response.status_code).to eq(404)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/remote-follow", HTML_HEADERS
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/remote-follow", JSON_HEADERS
      expect(response.status_code).to eq(200)
    end

    it "renders a form" do
      get "/actors/#{actor.username}/remote-follow", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='domain']]")).not_to be_empty
    end

    it "returns a template" do
      get "/actors/#{actor.username}/remote-follow", JSON_HEADERS
      expect(JSON.parse(response.body).dig?("domain")).not_to be_nil
    end

    it "includes the target" do
      get "/actors/#{actor.username}/remote-follow", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='target']/@value").first).to eq(actor.iri)
    end

    it "includes the target" do
      get "/actors/#{actor.username}/remote-follow", JSON_HEADERS
      expect(JSON.parse(response.body).dig?("target")).to eq(actor.iri)
    end

    it "includes the action" do
      get "/actors/#{actor.username}/remote-follow", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='action']/@value").first).to eq("follow")
    end

    it "includes the action" do
      get "/actors/#{actor.username}/remote-follow", JSON_HEADERS
      expect(JSON.parse(response.body).dig?("action")).to eq("follow")
    end

    it "renders the message" do
      get "/actors/#{actor.username}/remote-follow", HTML_HEADERS
      expect(XML.parse_html(response.body).xpath_nodes("//h1").first).to match(/Follow Actor/)
    end
  end

  describe "POST /remote-interaction" do
    it "returns 400 if target is missing" do
      post "/remote-interaction", HTML_HEADERS, ""
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if target is missing" do
      post "/remote-interaction", JSON_HEADERS, "{}"
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if action is missing" do
      post "/remote-interaction", HTML_HEADERS, "target=#{URI.encode_path(actor.iri)}"
      expect(response.status_code).to eq(400)
    end

    it "returns 400 if action is missing" do
      post "/remote-interaction", JSON_HEADERS, %Q|{"target":#{object.iri.to_json}}|
      expect(response.status_code).to eq(400)
    end

    it "renders an error if domain is missing" do
      post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}"
      expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/p").first).to match(/The domain must not be blank/)
    end

    it "returns an error if domain is missing" do
      post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json}}|
      expect(JSON.parse(response.body).dig?("msg")).to match(/The domain must not be blank/)
    end

    it "renders an error if domain is blank" do
      post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}&domain="
      expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/p").first).to match(/The domain must not be blank/)
    end

    it "returns an error if domain is blank" do
      post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json},"domain":""}|
      expect(JSON.parse(response.body).dig?("msg")).to match(/The domain must not be blank/)
    end

    it "retains the domain if domain doesn't exist" do
      post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}&domain=no-such-host"
      expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='domain']/@value").first).to eq("no-such-host")
    end

    it "retains the domain if domain doesn't exist" do
      post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json},"domain":"no-such-host"}|
      expect(JSON.parse(response.body).dig?("domain")).to eq("no-such-host")
    end

    it "redirects if succesful" do
      post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}&domain=remote.com"
      expect(response.status_code).to eq(302)
    end

    it "succeeds" do
      post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json},"domain":"remote.com"}|
      expect(response.status_code).to eq(200)
    end

    it "returns the remote location if successful" do
      post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}&domain=remote.com"
      expect(response.headers["Location"]?).to eq("https://remote.com/authorize-interaction?uri=#{actor.iri}")
    end

    it "returns the remote location if successful" do
      post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json},"domain":"remote.com"}|
      expect(JSON.parse(response.body).dig?("location")).to eq("https://remote.com/authorize-interaction?uri=#{object.iri}")
    end

    context "given a handle instead of a domain" do
      it "redirects if succesful" do
        post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}&domain=foobar%40remote.com"
        expect(response.status_code).to eq(302)
      end

      it "succeeds" do
        post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json},"domain":"foobar@remote.com"}|
        expect(response.status_code).to eq(200)
      end

      it "returns the remote location if successful" do
        post "/remote-interaction", HTML_HEADERS, "action=follow&target=#{URI.encode_path(actor.iri)}&domain=foobar%40remote.com"
        expect(response.headers["Location"]?).to eq("https://remote.com/authorize-interaction?uri=#{actor.iri}")
      end

      it "returns the remote location if successful" do
        post "/remote-interaction", JSON_HEADERS, %Q|{"action":"reply","target":#{object.iri.to_json},"domain":"foobar@remote.com"}|
        expect(JSON.parse(response.body).dig?("location")).to eq("https://remote.com/authorize-interaction?uri=#{object.iri}")
      end
    end
  end

  describe "GET /authorize-interaction" do
    it "returns 401 if not authorized" do
      get "/authorize-interaction"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 400 if the uri is missing" do
        get "/authorize-interaction"
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if the uri can't be dereferenced" do
        get "/authorize-interaction?uri=https://remote/returns-404"
        expect(response.status_code).to eq(400)
      end

      context "given an actor" do
        let_build(:actor, named: :foobar, iri: "https://remote/actors/foobar")

        before_each do
          HTTP::Client.actors << foobar
        end

        it "succeeds" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Factors%2Ffoobar", HTML_HEADERS
          expect(response.status_code).to eq(200)
        end

        it "succeeds" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Factors%2Ffoobar", JSON_HEADERS
          expect(response.status_code).to eq(200)
        end

        it "renders the remote actor" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Factors%2Ffoobar", HTML_HEADERS
          expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@value='Follow']][.//input[@value='https://remote/actors/foobar']]")).not_to be_empty
        end

        it "returns the actor" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Factors%2Ffoobar", JSON_HEADERS
          expect(JSON.parse(response.body)["id"]?).to eq("https://remote/actors/foobar")
        end

        context "with a public key" do
          before_each do
            foobar.assign(pem_public_key: "OLD PEM PUBLIC KEY").save
            HTTP::Client.actors << foobar.assign(pem_public_key: "NEW PEM PUBLIC KEY")
          end

          it "updates the public key" do
            expect { get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Factors%2Ffoobar", HTML_HEADERS }
              .to change { foobar.reload!.pem_public_key }.to("NEW PEM PUBLIC KEY")
          end
        end

        context "that is local" do
          before_each { foobar.assign(iri: "https://test.test/actors/foobar").save }

          it "doesn't fetch the actor" do
            expect { get "/authorize-interaction?uri=https%3A%2F%2Ftest.test%2Factors%2Ffoobar", HTML_HEADERS }.not_to change { ActivityPub::Actor.count }
            expect(HTTP::Client.requests).not_to have("GET #{foobar.iri}")
          end
        end

        context "that is down" do
          before_each { foobar.save.down! }

          it "marks the actor as up" do
            expect { get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Factors%2Ffoobar", HTML_HEADERS }.to change { foobar.reload!.up? }.to(true)
          end
        end
      end

      context "given an object" do
        let_build(:object, named: :foobar, iri: "https://remote/objects/foobar")

        before_each do
          HTTP::Client.objects << foobar
          HTTP::Client.actors << foobar.attributed_to
        end

        it "succeeds" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Fobjects%2Ffoobar", HTML_HEADERS
          expect(response.status_code).to eq(200)
        end

        it "succeeds" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Fobjects%2Ffoobar", JSON_HEADERS
          expect(response.status_code).to eq(200)
        end

        it "renders the remote object" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Fobjects%2Ffoobar", HTML_HEADERS
          expect(XML.parse_html(response.body).xpath_nodes("//a[@href='https://remote/objects/foobar'][text()='Source']")).not_to be_empty
        end

        it "returns the object" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Fobjects%2Ffoobar", JSON_HEADERS
          expect(JSON.parse(response.body)["id"]?).to eq("https://remote/objects/foobar")
        end

        context "that is local" do
          before_each { foobar.assign(iri: "https://test.test/objects/foobar").save }

          it "doesn't fetch the object" do
            expect { get "/authorize-interaction?uri=https%3A%2F%2Ftest.test%2Fobjects%2Ffoobar", HTML_HEADERS }.not_to change { ActivityPub::Object.count }
            expect(HTTP::Client.requests).not_to have("GET #{foobar.iri}")
          end
        end
      end
    end
  end
end
