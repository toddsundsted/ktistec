require "../../src/controllers/tags"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe TagsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(author) { register.actor }

  macro create_tagged_object(index, origin, *tags)
    let_create(
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
    {% for tag in tags %}
      let_create!(
        :hashtag, named: nil,
        name: {{tag}},
        subject: object{{index}}
      )
    {% end %}
  end

  describe "GET /tags/:hashtag" do
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

  let(body) { XML.parse_html(response.body) }

  TURBO_FRAME = HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "tag_page_tag_controls"}

  describe "POST /tags/:hashtag/follow" do
    create_tagged_object(1, :local, "foo")
    create_tagged_object(2, :remote, "bar")

    it "returns 401" do
      post "/tags/unknown/follow"
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in(as: author.username)

      it "succeeds" do
        post "/tags/foo/follow"
        expect(response.status_code).to eq(302)
      end

      it "follows the tag" do
        post "/tags/foo/follow"
        expect(Relationship::Content::Follow::Hashtag.all.map(&.to_iri)).to contain_exactly("foo")
      end

      it "begins fetching the tag" do
        post "/tags/foo/follow"
        expect(Task::Fetch::Hashtag.all.map(&.name)).to contain_exactly("foo")
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/tags/foo/follow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders an unfollow button" do
          post "/tags/foo/follow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='tag_page_tag_controls']//button")).to have("Unfollow")
        end
      end

      context "given an existing follow and fetch" do
        let_create!(:follow_hashtag_relationship, actor: author, name: "foo")
        let_create!(:fetch_hashtag_task, source: author, name: "foo")

        it "succeeds" do
          post "/tags/foo/follow"
          expect(response.status_code).to eq(302)
        end

        it "does not change the count of follow relationships" do
          expect{post "/tags/foo/follow"}.
            not_to change{Relationship::Content::Follow::Hashtag.count(name: "foo")}
        end

        it "does not change the count of fetch tasks" do
          expect{post "/tags/foo/follow"}.
            not_to change{Task::Fetch::Hashtag.count(name: "foo")}
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/tags/foo/follow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders an unfollow button" do
            post "/tags/foo/follow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='tag_page_tag_controls']//button")).to have("Unfollow")
          end
        end
      end

      it "returns 404 if no tagged objects exist" do
        post "/tags/foobar/follow"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /tags/:hashtag/unfollow" do
    create_tagged_object(1, :local, "foo")
    create_tagged_object(2, :remote, "bar")

    it "returns 401" do
      post "/tags/unknown/unfollow"
      expect(response.status_code).to eq(401)
    end

    context "when authenticated" do
      sign_in(as: author.username)

      it "succeeds" do
        post "/tags/foo/unfollow"
        expect(response.status_code).to eq(302)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/tags/foo/unfollow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders a follow button" do
          post "/tags/foo/unfollow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='tag_page_tag_controls']//button")).to have("Follow")
        end
      end

      context "given a follow and a fetch" do
        let_create!(:follow_hashtag_relationship, actor: author, name: "foo")
        let_create!(:fetch_hashtag_task, source: author, name: "foo")

        it "succeeds" do
          post "/tags/foo/unfollow"
          expect(response.status_code).to eq(302)
        end

        it "unfollows the tag" do
          post "/tags/foo/unfollow"
          expect(Relationship::Content::Follow::Hashtag.all.map(&.to_iri)).to be_empty
        end

        it "stops fetching the hashtag" do
          post "/tags/foo/unfollow"
          expect(Task::Fetch::Hashtag.where(complete: true).map(&.subject_iri)).to eq(["foo"])
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/tags/foo/unfollow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders a follow button" do
            post "/tags/foo/unfollow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='tag_page_tag_controls']//button")).to have("Follow")
          end
        end
      end

      it "returns 404 if no tagged objects exist" do
        post "/tags/foobar/unfollow"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
