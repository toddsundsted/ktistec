require "../../src/controllers/mentions"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe MentionsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(author) { register.actor }

  def mention_href(handle)
    user, _, host = handle.partition("@")
    "https://#{host}/users/#{user}"
  end

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
        href: mention_href({{mention}}),
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
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id"))
          .to contain_exactly("object-#{object3.id}", "object-#{object1.id}")
      end

      it "renders the collection" do
        get "/mentions/bar%40remote", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a)
          .to contain_exactly(object3.iri, object1.iri)
      end

      it "renders the collection" do
        get "/mentions/foo%40remote", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id"))
          .to contain_exactly("object-#{object5.id}", "object-#{object4.id}", "object-#{object3.id}", "object-#{object2.id}", "object-#{object1.id}")
      end

      it "renders the collection" do
        get "/mentions/foo%40remote", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a)
          .to contain_exactly(object5.iri, object4.iri, object3.iri, object2.iri, object1.iri)
      end

      it "returns 404 if no such mention exists" do
        get "/mentions/remote"
        expect(response.status_code).to eq(404)
      end

      describe "turbo-stream-source pagination" do
        it "includes turbo-stream-source on first page" do
          get "/mentions/foo%40remote", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(response.body).to contain("turbo-stream-source")
        end

        it "does not include turbo-stream-source on subsequent pages" do
          get "/mentions/foo%40remote?max_id=100", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(response.body).not_to contain("turbo-stream-source")
        end
      end

      # a bare handle

      it "redirects to the qualified handle" do
        get "/mentions/foo", ACCEPT_HTML
        expect(response.status_code).to eq(301)
        expect(response.headers["Location"]).to eq("/mentions/foo%40remote")
      end

      it "redirects to the qualified handle" do
        get "/mentions/foo", ACCEPT_JSON
        expect(response.status_code).to eq(301)
        expect(response.headers["Location"]).to eq("/mentions/foo%40remote")
      end

      it "returns 404 when nothing matches" do
        get "/mentions/nobody", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 when nothing matches" do
        get "/mentions/nobody", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      context "given another matching tag" do
        create_object_with_mentions(2, "foo@other")

        it "returns 404 when the match is ambiguous" do
          get "/mentions/foo", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end

        it "returns 404 when the match is ambiguous" do
          get "/mentions/foo", ACCEPT_JSON
          expect(response.status_code).to eq(404)
        end
      end

      context "given a tag with no href" do
        let_create(
          :object,
          attributed_to: author,
          published: Time.utc(2016, 2, 15, 10, 20, 9),
        )
        let_create!(
          :mention,
          name: "ghost@remote",
          href: nil,
          subject: object,
        )

        it "returns 404" do
          get "/mentions/ghost", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end

        it "returns 404" do
          get "/mentions/ghost", ACCEPT_JSON
          expect(response.status_code).to eq(404)
        end
      end
    end
  end

  let(body) { XML.parse_html(response.body) }

  TURBO_FRAME = HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "mention_page_mention_banner"}

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
        expect(Relationship::Content::Follow::Mention.all.map(&.to_iri)).to contain_exactly(mention_href("foo@remote"))
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/mentions/foo%40remote/follow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders an unfollow button" do
          post "/mentions/foo%40remote/follow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='mention_page_mention_banner']//button")).to have("Unfollow")
        end
      end

      context "given an existing follow" do
        let_create!(:follow_mention_relationship, named: nil, actor: author, href: mention_href("foo@remote"))

        it "succeeds" do
          post "/mentions/foo%40remote/follow"
          expect(response.status_code).to eq(302)
        end

        it "does not change the count of mention relationships" do
          expect { post "/mentions/foo%40remote/follow" }
            .not_to change { Relationship::Content::Follow::Mention.count(href: mention_href("foo@remote")) }
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/mentions/foo%40remote/follow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders an unfollow button" do
            post "/mentions/foo%40remote/follow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='mention_page_mention_banner']//button")).to have("Unfollow")
          end
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

      it "succeeds" do
        post "/mentions/foo%40remote/unfollow"
        expect(response.status_code).to eq(302)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/mentions/foo%40remote/unfollow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders a follow button" do
          post "/mentions/foo%40remote/unfollow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='mention_page_mention_banner']//button")).to have("Follow")
        end
      end

      context "given an existing follow" do
        let_create!(:follow_mention_relationship, named: nil, actor: author, href: mention_href("foo@remote"))

        it "succeeds" do
          post "/mentions/foo%40remote/unfollow"
          expect(response.status_code).to eq(302)
        end

        it "unfollows the mention" do
          post "/mentions/foo%40remote/unfollow"
          expect(Relationship::Content::Follow::Mention.all.map(&.to_iri)).to be_empty
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/mentions/foo%40remote/unfollow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders a follow button" do
            post "/mentions/foo%40remote/unfollow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='mention_page_mention_banner']//button")).to have("Follow")
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
