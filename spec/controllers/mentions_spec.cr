require "../../src/controllers/mentions"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe MentionsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(author) { register.actor }

  macro create_object_with_mentions(index, *mentions)
    let_create(
      :object, named: object{{index}},
      attributed_to: author,
      published: Time.utc(2016, 2, 15, 10, 20, {{index}})
    )
    {% for mention in mentions %}
      let_create!(
        :mention, named: nil,
        name: {{mention}},
        subject: object{{index}}
      )
    {% end %}
  end

  describe "GET /mentions" do
    create_object_with_mentions(1, "foo@remote", "bar@remote")
    create_object_with_mentions(2, "foo@remote")
    create_object_with_mentions(3, "foo@remote", "bar@remote")
    create_object_with_mentions(4, "foo@remote")
    create_object_with_mentions(5, "foo@remote", "quux@remote")

    it "returns 401" do
      get "/mentions/foo%40remote", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401" do
      get "/mentions/foo%40remote", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in

      it "succeeds" do
        get "/mentions/foo%40remote", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/mentions/foo%40remote", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the collection" do
        get "/mentions/bar%40remote", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).
          to contain_exactly("object-#{object3.id}", "object-#{object1.id}")
      end

      it "renders the collection" do
        get "/mentions/bar%40remote", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).
          to contain_exactly(object3.iri, object1.iri)
      end

      it "renders the collection" do
        get "/mentions/foo%40remote", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).
          to contain_exactly("object-#{object5.id}", "object-#{object4.id}", "object-#{object3.id}", "object-#{object2.id}", "object-#{object1.id}")
      end

      it "renders the collection" do
        get "/mentions/foo%40remote", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).
          to contain_exactly(object5.iri, object4.iri, object3.iri, object2.iri, object1.iri)
      end

      it "returns 404 if no such mention exists" do
        get "/mentions/remote"
        expect(response.status_code).to eq(404)
      end
    end
  end

  let(body) { XML.parse_html(response.body) }

  TURBO_FRAME = HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "mention_page_mention_controls"}

  alias Mention = Relationship::Content::Follow::Mention

  describe "POST /mentions/follow" do
    create_object_with_mentions(1, "foo@remote")
    create_object_with_mentions(2, "bar@remote")

    it "returns 401" do
      post "/mentions/foo%40remote/follow"
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in(as: author.username)

      it "succeeds" do
        post "/mentions/foo%40remote/follow"
        expect(response.status_code).to eq(302)
      end

      it "follows the mention" do
        post "/mentions/foo%40remote/follow"
        expect(Mention.all.map(&.to_iri)).to contain_exactly("foo@remote")
      end

      context "given a follow" do
        let_create!(:follow_mention_relationship, named: nil, actor: author, name: "foo@remote")

        it "returns 400" do
          post "/mentions/foo%40remote/follow"
          expect(response.status_code).to eq(400)
        end
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/mentions/foo%40remote/follow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders an unfollow button" do
          post "/mentions/foo%40remote/follow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='mention_page_mention_controls']//button")).to have("Unfollow")
        end
      end

      it "returns 404 if no mentioned objects exist" do
        post "/mentions/foobar@remote/follow"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /mentions/unfollow" do
    create_object_with_mentions(1, "foo@remote")
    create_object_with_mentions(2, "bar@remote")

    it "returns 401" do
      post "/mentions/foo%40remote/unfollow"
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in(as: author.username)

      it "returns 400" do
        post "/mentions/foo%40remote/unfollow"
        expect(response.status_code).to eq(400)
      end

      context "given a follow" do
        let_create!(:follow_mention_relationship, named: nil, actor: author, name: "foo@remote")

        it "succeeds" do
          post "/mentions/foo%40remote/unfollow"
          expect(response.status_code).to eq(302)
        end

        it "unfollows the mention" do
          post "/mentions/foo%40remote/unfollow"
          expect(Mention.all.map(&.to_iri)).to be_empty
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/mentions/foo%40remote/unfollow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders a follow button" do
            post "/mentions/foo%40remote/unfollow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='mention_page_mention_controls']//button")).to have("Follow")
          end
        end
      end

      it "returns 404 if no mentioned objects exist" do
        post "/mentions/foobar@remote/unfollow"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
