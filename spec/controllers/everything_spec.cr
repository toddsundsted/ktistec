require "../../src/controllers/everything"

require "../spec_helper/controller"

Spectator.describe EverythingController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  describe "/everything" do
    sign_in

    let(author) { ActivityPub::Actor.new(iri: "https://test.test/actors/author") }

    macro create_post(index)
      let!(post{{index}}) do
        ActivityPub::Object.new(
          iri: "https://test.test/objects/{{index}}",
          attributed_to: author,
          published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
          visible: true
        ).save
      end
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
      expect(XML.parse_html(response.body).xpath_nodes("//article/@id")).to contain_exactly("object-#{post5.id}", "object-#{post4.id}")
    end

    it "renders the collection" do
      get "/everything?size=2", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to contain_exactly(post5.iri, post4.iri)
    end
  end
end
