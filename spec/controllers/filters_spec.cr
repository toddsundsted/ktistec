require "../../src/controllers/filters"

require "../spec_helper/factory"
require "../spec_helper/controller"

# redefine as public for testing
class FiltersController
  def self.get_filter_term(env, id)
    previous_def(env, id)
  end
end

Spectator.describe FiltersController do
  setup_spec

  let(actor) { register.actor }

  describe ".get_filter_term" do
    let(env) { make_env("GET", "/") }

    let_create!(:filter_term, named: test_term, actor: actor, term: "test")
    let_create!(:filter_term, named: other_term, term: "other")

    context "when unauthenticated" do
      it "returns nil" do
        result = FiltersController.get_filter_term(env, test_term.id)
        expect(result).to be_nil
      end
    end

    context "when authenticated" do
      sign_in(as: actor.username)

      it "returns the owned filter term" do
        result = FiltersController.get_filter_term(env, test_term.id)
        expect(result).to eq(test_term)
      end

      it "returns nil if user does not own the term" do
        result = FiltersController.get_filter_term(env, other_term.id)
        expect(result).to be_nil
      end

      it "returns nil if the term does not exist" do
        result = FiltersController.get_filter_term(env, 999999_i64)
        expect(result).to be_nil
      end
    end
  end

  describe "GET /filters" do
    ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
    ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

    it "returns 401 if not authorized" do
      get "/filters", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/filters", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      let_create!(:filter_term, named: term1, actor: actor, term: "foo")
      let_create!(:filter_term, named: term2, actor: actor, term: "bar")
      let_create!(:filter_term, term: "baz")

      it "succeeds" do
        get "/filters", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/filters", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the collection" do
        get "/filters", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'term')]/@id")).to contain_exactly("term-#{term1.id}", "term-#{term2.id}")
      end

      it "renders the collection" do
        get "/filters", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(term1.iri, term2.iri)
      end
    end
  end

  describe "POST /filters" do
    HTML_HEADERS = HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"}
    JSON_HEADERS = HTTP::Headers{"Accept" => "application/json", "Content-Type" => "application/json"}

    it "returns 401 if not authorized" do
      post "/filters", HTML_HEADERS
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      post "/filters", JSON_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/filters", HTML_HEADERS, "term=Foo+Bar"
        expect(response.status_code).to eq(302)
      end

      it "succeeds" do
        post "/filters", JSON_HEADERS, %q|{"term":"Foo+Bar"}|
        expect(response.status_code).to eq(302)
      end

      it "adds a new content filter term" do
        expect { post "/filters", HTML_HEADERS, "term=Foo+Bar" }
          .to change { FilterTerm.count }
      end

      it "adds a new content filter term" do
        expect { post "/filters", JSON_HEADERS, %q|{"term":"Foo+Bar"}| }
          .to change { FilterTerm.count }
      end

      it "returns 422 if term is blank" do
        post "/filters", HTML_HEADERS, "term="
        expect(response.status_code).to eq(422)
      end

      it "returns 422 if term is blank" do
        post "/filters", JSON_HEADERS, %q|{"term":""}|
        expect(response.status_code).to eq(422)
      end

      it "renders an error message if term is blank" do
        post "/filters", HTML_HEADERS, "term="
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/can't be blank/)
      end

      it "returns an error message if term is blank" do
        post "/filters", JSON_HEADERS, %q|{"term":""}|
        expect(JSON.parse(response.body)["errors"].as_h).to have_value(["can't be blank"])
      end

      context "given existing terms" do
        let_create!(:filter_term, actor: actor, term: "hey")

        it "returns 422 if term already exists" do
          post "/filters", HTML_HEADERS, "term=hey"
          expect(response.status_code).to eq(422)
        end

        it "returns 422 if term already exists" do
          post "/filters", JSON_HEADERS, %q|{"term":"hey"}|
          expect(response.status_code).to eq(422)
        end

        it "renders an error message if term already exists" do
          post "/filters", HTML_HEADERS, "term=hey"
          expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/already exists: hey/)
        end

        it "renders an error message if term already exists" do
          post "/filters", JSON_HEADERS, %q|{"term":"hey"}|
          expect(JSON.parse(response.body)["errors"].as_h).to have_value(["already exists: hey"])
        end
      end
    end
  end

  describe "DELETE /filters/:id" do
    HTML_HEADERS = HTTP::Headers{"Accept" => "text/html", "Content-Type" => "application/x-www-form-urlencoded"}
    JSON_HEADERS = HTTP::Headers{"Accept" => "application/json", "Content-Type" => "application/json"}

    it "returns 401 if not authorized" do
      delete "/filters/0", HTML_HEADERS
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      delete "/filters/0", JSON_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if term does not exist" do
        delete "/filters/999999", HTML_HEADERS
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if term does not exist" do
        delete "/filters/999999", JSON_HEADERS
        expect(response.status_code).to eq(404)
      end

      context "given existing terms" do
        let_create!(:filter_term, named: term1, actor: actor, term: "hey")
        let_create!(:filter_term, named: term2, term: "hey")

        it "returns 404 if term does not belong to the actor" do
          delete "/filters/#{term2.id}", HTML_HEADERS
          expect(response.status_code).to eq(404)
        end

        it "returns 404 if term does not belong to the actor" do
          delete "/filters/#{term2.id}", JSON_HEADERS
          expect(response.status_code).to eq(404)
        end

        it "redirects if successful" do
          delete "/filters/#{term1.id}", HTML_HEADERS
          expect(response.status_code).to eq(302)
        end

        it "redirects if successful" do
          delete "/filters/#{term1.id}", JSON_HEADERS
          expect(response.status_code).to eq(302)
        end

        it "destroys the term" do
          expect { delete "/filters/#{term1.id}", HTML_HEADERS }
            .to change { FilterTerm.count }
        end

        it "destroys the term" do
          expect { delete "/filters/#{term1.id}", JSON_HEADERS }
            .to change { FilterTerm.count }
        end
      end
    end
  end
end
