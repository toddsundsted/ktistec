require "../../src/controllers/everything"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe EverythingController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  describe "GET /everything" do
    it "returns 401 if not authorized" do
      get "/everything", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/everything", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      let_build(:actor, named: :author)

      macro create_post(index)
        let_create!(
          :object, named: post{{index}},
          attributed_to: author,
          published: Time.utc(2016, 2, 15, 10, 20, {{index}})
        )
      end

      create_post(1)
      create_post(2)
      create_post(3)
      create_post(4)
      create_post(5)

      it "succeeds" do
        get "/everything", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/everything", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the collection" do
        get "/everything?size=2", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{post5.id}", "object-#{post4.id}")
      end

      it "renders the collection" do
        get "/everything?size=2", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(post5.iri, post4.iri)
      end

      describe "turbo-stream-source pagination" do
        it "includes turbo-stream-source on first page" do
          get "/everything", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(response.body).to contain("turbo-stream-source")
        end

        it "excludes turbo-stream-source on subsequent pages" do
          get "/everything?page=2", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(response.body).to_not contain("turbo-stream-source")
        end
      end
    end
  end
end
