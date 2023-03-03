require "../../src/controllers/tags"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe TagsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  describe "/tags/:hashtag" do
    let_build(:actor, named: :author)

    macro create_tagged_object(index, origin, *tags)
      let_create!(
        :object, named: object{{index}},
        attributed_to: author,
        published: Time.utc(2016, 2, 15, 10, 20, {{index}}),
        local: {{
          if origin == :local
            true
          elsif origin == :remote
            false
          else
            raise "not supported: #{origin}"
          end
        }}
      )
      before_each do
        {% for tag in tags %}
          Factory.create(:hashtag, name: {{tag}}, subject: object{{index}})
        {% end %}
      end
    end

    create_tagged_object(1, :local, "foo", "bar")
    create_tagged_object(2, :local, "foo")
    create_tagged_object(3, :local, "foo", "bar")
    create_tagged_object(4, :remote, "foo")
    create_tagged_object(5, :remote, "foo", "quux")

    it "succeeds" do
      get "/tags/foo", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/tags/foo", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    it "renders the collection" do
      get "/tags/bar", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).
        to contain_exactly("object-#{object3.id}", "object-#{object1.id}")
    end

    it "renders the collection" do
      get "/tags/bar", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).
        to contain_exactly(object3.iri, object1.iri)
    end

    it "renders the collection" do
      get "/tags/foo", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).
        to contain_exactly("object-#{object3.id}", "object-#{object2.id}", "object-#{object1.id}")
    end

    it "renders the collection" do
      get "/tags/foo", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).
        to contain_exactly(object3.iri, object2.iri, object1.iri)
    end

    context "if authenticated" do
      sign_in

      it "renders the collection" do
        get "/tags/foo", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).
          to contain_exactly("object-#{object5.id}", "object-#{object4.id}", "object-#{object3.id}", "object-#{object2.id}", "object-#{object1.id}")
      end

      it "renders the collection" do
        get "/tags/foo", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).
          to contain_exactly(object5.iri, object4.iri, object3.iri, object2.iri, object1.iri)
      end
    end

    it "returns 404 if no tagged objects exist" do
      get "/tags/foobar"
      expect(response.status_code).to eq(404)
    end
  end
end
