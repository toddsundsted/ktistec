require "../../src/controllers/feeds"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe FeedsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(actor) { register.actor }

  let_create!(:feed, owner: actor)

  describe "GET /actors/:username/feeds/:id" do
    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed does not exist" do
        get "/actors/#{actor.username}/feeds/999999", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed does not exist" do
        get "/actors/#{actor.username}/feeds/999999", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed id is not numeric" do
        get "/actors/#{actor.username}/feeds/abc", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed id is not numeric" do
        get "/actors/#{actor.username}/feeds/abc", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      context "given a feed owned by another actor" do
        let_create!(:feed, named: other)

        it "returns 404" do
          get "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end

        it "returns 404" do
          get "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_JSON
          expect(response.status_code).to eq(404)
        end
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      context "given objects in the feed" do
        let_create(:object, named: earlier)
        let_create(:object, named: later)

        before_each do
          put_in_feed(feed, earlier)
          put_in_feed(feed, later)
        end

        it "renders the objects most recently arrived first" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{later.id}", "object-#{earlier.id}")
        end

        it "renders the objects most recently arrived first" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a.map(&.as_s)).to eq([later.iri, earlier.iri])
        end

        it "paginates the results" do
          get "/actors/#{actor.username}/feeds/#{feed.id}?limit=1", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{later.id}")
          expect(XML.parse_html(response.body).xpath_nodes("//nav[contains(@class,'pagination')]//a/@href")).to contain(/max-id=#{later.id}/)
        end

        it "paginates the results" do
          get "/actors/#{actor.username}/feeds/#{feed.id}?limit=1", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a.map(&.as_s)).to eq([later.iri])
        end

        it "paginates the results" do
          get "/actors/#{actor.username}/feeds/#{feed.id}?max_id=#{later.id}&limit=1", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("orderedItems").as_a.map(&.as_s)).to eq([earlier.iri])
        end

        context "given a verdict with a reason" do
          let_create!(:feed_verdict, feed: feed, object: later, reason: "matched: alpha")

          it "renders the reason" do
            get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
            expect(response.status_code).to eq(200)
            expect(response.body).to contain("matched: alpha")
          end
        end
      end
    end
  end
end
