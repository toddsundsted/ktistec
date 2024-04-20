require "../../src/controllers/interactions"

require "../spec_helper/factory"
require "../spec_helper/network"
require "../spec_helper/controller"

Spectator.describe InteractionsController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json"}

  let(actor) { register.actor }

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

      context "given a remote actor" do
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
      end

      context "given a remote object" do
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
          expect(XML.parse_html(response.body).xpath_nodes("//a[.//button[text()='Source']][@href='https://remote/objects/foobar']")).not_to be_empty
        end

        it "returns the object" do
          get "/authorize-interaction?uri=https%3A%2F%2Fremote%2Fobjects%2Ffoobar", JSON_HEADERS
          expect(JSON.parse(response.body)["id"]?).to eq("https://remote/objects/foobar")
        end
      end
    end
  end
end
