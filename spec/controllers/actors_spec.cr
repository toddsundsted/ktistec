require "../../src/controllers/actors"

require "../spec_helper/controller"
require "../spec_helper/factory"

# redefine as public for testing
class ActorsController
  def self.get_account(env)
    previous_def(env)
  end

  def self.get_account_with_ownership(env)
    previous_def(env)
  end

  def self.get_actor(env)
    previous_def(env)
  end
end

Spectator.describe ActorsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(actor) { register.actor }

  describe ".get_account" do
    let(account) { register }

    it "returns nil" do
      env = env_factory("GET", "/actors/nonexistent/posts")
      result = ActorsController.get_account(env)
      expect(result).to be_nil
    end

    it "returns account" do
      env = env_factory("GET", "/actors/#{account.username}/posts")
      result = ActorsController.get_account(env)
      expect(result).to eq(account)
    end
  end

  describe ".get_account_with_ownership" do
    let(account) { register }

    it "returns nil" do
      env = env_factory("GET", "/actors/nonexistent/posts")
      result = ActorsController.get_account_with_ownership(env)
      expect(result).to be_nil
    end

    it "returns nil" do
      env = env_factory("GET", "/actors/#{account.username}/posts")
      result = ActorsController.get_account_with_ownership(env)
      expect(result).to be_nil
    end

    context "when authenticated" do
      sign_in(as: account.username)

      it "returns account" do
        env = env_factory("GET", "/actors/#{account.username}/posts")
        result = ActorsController.get_account_with_ownership(env)
        expect(result).to eq(account)
      end

      context "given another account" do
        let(other_account) { register }

        it "returns nil" do
          env = env_factory("GET", "/actors/#{other_account.username}/posts")
          result = ActorsController.get_account_with_ownership(env)
          expect(result).to be_nil
        end
      end
    end
  end

  describe ".get_actor" do
    let_create!(:actor)

    it "returns nil" do
      result = ActorsController.get_actor(999999)
      expect(result).to be_nil
    end

    it "returns actor" do
      result = ActorsController.get_actor(actor.id)
      expect(result).to eq(actor)
    end
  end

  describe "GET /actors/:username" do
    it "returns 404 if not found" do
      get "/actors/missing", ACCEPT_HTML
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      get "/actors/missing", ACCEPT_JSON
      expect(response.status_code).to eq(404)
    end

    it "returns 200 if found" do
      get "/actors/#{actor.username}", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "returns 200 if found" do
      get "/actors/#{actor.username}", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    it "responds with HTML" do
      get "/actors/#{actor.username}", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
    end

    it "responds with JSON" do
      get "/actors/#{actor.username}", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("type")).to be_truthy
    end

    context "when authorized" do
      sign_in(as: actor.username)

      let_build(:create)
      let_build(:announce)

      before_each do
        put_in_outbox(owner: actor, activity: create)
        Factory.create(:timeline_create, owner: actor, object: create.object)
        put_in_outbox(owner: actor, activity: announce)
        Factory.create(:timeline_announce, owner: actor, object: announce.object)
      end

      it "with no filters it renders all posts" do
        get "/actors/#{actor.username}?filters=none", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create", "event activity-announce").in_any_order
      end

      it "filters out shares from posts" do
        get "/actors/#{actor.username}?filters=no-shares", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
      end

      context "given a reply" do
        before_each { create.object.assign(in_reply_to: announce.object).save }

        it "with no filters it renders all posts" do
          get "/actors/#{actor.username}?filters=none", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create", "event activity-announce").in_any_order
        end

        it "filters out replies from posts" do
          get "/actors/#{actor.username}?filters=no-replies", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
        end
      end

      describe "filter preferences" do
        it "stores filter preferences in session" do
          get "/actors/#{actor.username}?filters=custom-filter", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(Global.session.not_nil!.string?("timeline_filters")).to eq("custom-filter")
        end

        it "handles empty filters gracefully" do
          Global.session.not_nil!.delete("timeline_filters")
          get "/actors/#{actor.username}", ACCEPT_HTML
          expect(response.status_code).to eq(200)
        end

        it "handles empty filters gracefully" do
          Global.session.not_nil!.string("timeline_filters", "")
          get "/actors/#{actor.username}", ACCEPT_HTML
          expect(response.status_code).to eq(200)
        end

        it "uses stored filters and redirects" do
          Global.session.not_nil!.string("timeline_filters", "custom-filter")
          get "/actors/#{actor.username}", ACCEPT_HTML
          expect(response.status_code).to eq(302)
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}?filters=custom-filter")
        end

        it "removes the query string" do
          Global.session.not_nil!.string("timeline_filters", "custom-filter")
          get "/actors/#{actor.username}?filters=", ACCEPT_HTML
          expect(response.status_code).to eq(302)
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}")
        end

        it "clears stored filters" do
          Global.session.not_nil!.string("timeline_filters", "custom-filter")
          get "/actors/#{actor.username}?filters=", ACCEPT_HTML
          expect(Global.session.not_nil!.string?("timeline_filters")).to be_nil
        end
      end
    end

    describe "filter preferences" do
      it "does not store filter preferences" do
        get "/actors/#{actor.username}?filters=custom-filter", ACCEPT_HTML
        expect(response.status_code).to eq(200)
        expect(Global.session).to be_nil
      end
    end

    it "includes RSS feed discovery link in HTML head when unauthenticated" do
      get "/actors/#{actor.username}", ACCEPT_HTML
      expect(response.status_code).to eq(200)
      html = XML.parse_html(response.body)
      rss_link = html.xpath_node("//link[@rel='alternate'][@type='application/rss+xml'][@href='/actors/#{actor.username}/feed.rss']")
      expect(rss_link.try(&.["title"])).to eq("#{actor.display_name}: RSS Feed")
    end
  end

  describe "GET /actors/:username/feed.rss" do
    it "returns 404 if not found" do
      get "/actors/missing/feed.rss"
      expect(response.status_code).to eq(404)
    end

    it "returns correct content type" do
      get "/actors/#{actor.username}/feed.rss"
      expect(response.status_code).to eq(200)
      expect(response.headers["Content-Type"]).to eq("application/rss+xml; charset=utf-8")
    end

    it "returns valid RSS" do
      get "/actors/#{actor.username}/feed.rss"
      expect(response.status_code).to eq(200)
      xml = XML.parse(response.body)
      expect(xml.xpath_node("//rss")).to_not be_nil
      expect(xml.xpath_node("//channel")).to_not be_nil
    end

    let_build(:create, actor: actor)

    it "includes public posts in RSS feed" do
      put_in_outbox(owner: actor, activity: create)

      get "/actors/#{actor.username}/feed.rss"
      expect(response.status_code).to eq(200)
      xml = XML.parse(response.body)
      expect(xml.xpath_nodes("//item")).to_not be_empty
      expect(xml.xpath_node("//item/title")).to_not be_nil
      expect(xml.xpath_node("//item/link")).to_not be_nil
      expect(xml.xpath_node("//item/description")).to_not be_nil
      expect(xml.xpath_node("//item/pubDate")).to_not be_nil
      expect(xml.xpath_node("//item/guid")).to_not be_nil
    end

  end

  describe "GET /actors/:username/public-posts" do
    it "returns 404 if not found" do
      get "/actors/missing/public-posts", ACCEPT_HTML
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      get "/actors/missing/public-posts", ACCEPT_JSON
      expect(response.status_code).to eq(404)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    let_build(:object, attributed_to: author, visible: true)
    let_build(:create, actor: author, object: object)
    let_build(:announce, actor: actor, object: object)

    context "when author is local" do
      let(author) { actor }

      pre_condition { expect(object.local?).to be_true }

      context "given a create" do
        before_each { put_in_outbox(owner: actor, activity: create) }

        it "renders the object's create aspect" do
          get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
        end
      end

      context "given an announce" do
        before_each { put_in_outbox(owner: actor, activity: announce) }

        it "renders the object's announce aspect" do
          get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
        end
      end

      context "given a create and an announce" do
        before_each do
          put_in_outbox(owner: actor, activity: create)
          put_in_outbox(owner: actor, activity: announce)
        end

        it "renders the object's create aspect" do
          get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
        end
      end
    end

    context "when author is remote" do
      let_build(:actor, named: :author)

      pre_condition { expect(object.local?).to be_false }

      context "given a create and an announce" do
        before_each do
          put_in_inbox(owner: actor, activity: create)
          put_in_outbox(owner: actor, activity: announce)
        end

        it "renders the object's announce aspect" do
          get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
        end
      end
    end

    it "renders the collection" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).to be_empty
    end

    it "renders the collection" do
      get "/actors/#{actor.username}/public-posts", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
    end
  end

  describe "GET /actors/:username/posts" do
    it "returns 401 if not authorized" do
      get "/actors/missing/posts", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/posts", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/posts", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/posts", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/posts", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/posts", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/posts", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/posts", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      let_build(:object, attributed_to: author, visible: true)
      let_build(:create, actor: author, object: object)
      let_build(:announce, actor: actor, object: object)

      context "when author is local" do
        let(author) { actor }

        pre_condition { expect(object.local?).to be_true }

        context "given a create" do
          before_each { put_in_outbox(owner: actor, activity: create) }

          it "renders the object's create aspect" do
            get "/actors/#{actor.username}/posts", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
          end
        end

        context "given an announce" do
          before_each { put_in_outbox(owner: actor, activity: announce) }

          it "renders the object's announce aspect" do
            get "/actors/#{actor.username}/posts", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
          end
        end

        context "given a create and an announce" do
          before_each do
            put_in_outbox(owner: actor, activity: create)
            put_in_outbox(owner: actor, activity: announce)
          end

          it "renders the object's create aspect" do
            get "/actors/#{actor.username}/posts", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
          end
        end
      end

      context "when author is remote" do
        let_build(:actor, named: :author)

        pre_condition { expect(object.local?).to be_false }

        context "given a create and an announce" do
          before_each do
            put_in_inbox(actor, create)
            put_in_outbox(actor, announce)
          end

          it "renders the object's announce aspect" do
            get "/actors/#{actor.username}/posts", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
          end
        end
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/posts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).to be_empty
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/posts", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
      end
    end
  end

  describe "GET /actors/:username/bookmarks" do
    it "returns 401 if not authorized" do
      get "/actors/missing/bookmarks", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/bookmarks", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/bookmarks", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/bookmarks", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/bookmarks", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/bookmarks", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/bookmarks", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/bookmarks", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      context "with bookmarked objects" do
        let_create(:object, named: :note, visible: true, published: Time.utc)
        let_create!(:bookmark_relationship, actor: actor, object: note)

        it "renders bookmarked objects" do
          get "/actors/#{actor.username}/bookmarks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).not_to be_empty
        end

        it "renders bookmarked objects" do
          get "/actors/#{actor.username}/bookmarks", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).not_to be_empty
        end
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/bookmarks", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).to be_empty
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/bookmarks", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
      end
    end
  end

  describe "GET /actors/:username/featured" do
    it "returns 404 if not found" do
      get "/actors/missing/featured", ACCEPT_HTML
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if not found" do
      get "/actors/missing/featured", ACCEPT_JSON
      expect(response.status_code).to eq(404)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/featured", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/actors/#{actor.username}/featured", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    context "with pinned/featured objects" do
      let_create(:object, named: note, attributed_to: actor, visible: true)
      let_create!(:pin_relationship, actor: actor, object: note)

      it "renders featured objects" do
        get "/actors/#{actor.username}/featured", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).not_to be_empty
      end

      it "renders featured objects" do
        get "/actors/#{actor.username}/featured", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).not_to be_empty
      end
    end

    it "renders an empty collection" do
      get "/actors/#{actor.username}/featured", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).to be_empty
    end

    it "renders an empty collection" do
      get "/actors/#{actor.username}/featured", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
    end
  end

  describe "GET /actors/:username/timeline" do
    it "returns 401 if not authorized" do
      get "/actors/missing/timeline", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/timeline", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/timeline", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/timeline", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/timeline", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/timeline", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/timeline", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/timeline", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "updates the last checked timestamp" do
        expect{get "/actors/#{actor.username}/timeline", ACCEPT_HTML}.
          to change{Account.find(username: actor.username).last_timeline_checked_at}
      end

      it "updates the last checked timestamp" do
        expect{get "/actors/#{actor.username}/timeline", ACCEPT_JSON}.
          to change{Account.find(username: actor.username).last_timeline_checked_at}
      end

      let_build(:object, attributed_to: author)
      let_build(:create, actor: author, object: object)
      let_build(:announce, actor: author, object: object)

      context "when author is the actor" do
        let(author) { actor }

        context "given a create" do
          before_each do
            put_in_outbox(owner: actor, activity: create)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object's create aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
          end
        end

        context "given an announce" do
          before_each do
            put_in_outbox(owner: actor, activity: announce)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object's announce aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
          end
        end
      end

      context "when author is not the actor" do
        let_build(:actor, named: :author)

        context "given a create" do
          before_each do
            put_in_inbox(owner: actor, activity: create)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object's create aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
          end
        end

        context "given an announce" do
          before_each do
            put_in_inbox(owner: actor, activity: announce)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object's announce aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
          end
        end

        context "given both a create and an announce outside of actor's mailbox" do
          before_each do
            create.save
            announce.save
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object without aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event")
          end
        end

        context "given a create, and an announce outside of actor's mailbox" do
          before_each do
            announce.save
            put_in_inbox(owner: actor, activity: create)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object's create aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
          end
        end

        context "given an announce, and a create outside of actor's mailbox" do
          before_each do
            create.save
            put_in_inbox(owner: actor, activity: announce)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object's announce aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
          end
        end

        let_build(:like, actor: author, object: object)

        context "given a like" do
          before_each do
            put_in_inbox(owner: actor, activity: like)
            put_in_timeline(owner: actor, object: object)
          end

          it "renders the object without aspect" do
            get "/actors/#{actor.username}/timeline", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event")
          end

          context "and a create" do
            before_each do
              put_in_inbox(owner: actor, activity: create)
            end

            it "renders the object's create aspect" do
              get "/actors/#{actor.username}/timeline", ACCEPT_HTML
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
            end
          end

          context "and an announce" do
            before_each do
              put_in_inbox(owner: actor, activity: announce)
            end

            it "renders the object's announce aspect" do
              get "/actors/#{actor.username}/timeline", ACCEPT_HTML
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
            end
          end
        end
      end

      it "renders an empty collection" do
        get "/actors/#{actor.username}/timeline", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).to be_empty
      end

      it "renders an empty collection" do
        get "/actors/#{actor.username}/timeline", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
      end

      describe "turbo-stream-source pagination" do
        it "includes turbo-stream-source on first page" do
          get "/actors/#{actor.username}/timeline", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(response.body).to contain("turbo-stream-source")
        end

        it "excludes turbo-stream-source on subsequent pages" do
          get "/actors/#{actor.username}/timeline?page=2", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(response.body).to_not contain("turbo-stream-source")
        end
      end
    end
  end

  describe "GET /actors/:username/notifications" do
    it "returns 401 if not authorized" do
      get "/actors/missing/notifications", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/notifications", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/notifications", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/notifications", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/notifications", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/notifications", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/notifications", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/notifications", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "updates the last checked timestamp" do
        expect{get "/actors/#{actor.username}/notifications", ACCEPT_HTML}.
          to change{Account.find(username: actor.username).last_notifications_checked_at}
      end

      it "updates the last checked timestamp" do
        expect{get "/actors/#{actor.username}/notifications", ACCEPT_JSON}.
          to change{Account.find(username: actor.username).last_notifications_checked_at}
      end

      it "renders an empty collection" do
        get "/actors/#{actor.username}/notifications", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]")).to be_empty
      end

      it "renders an empty collection" do
        get "/actors/#{actor.username}/notifications", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("first", "orderedItems").as_a).to be_empty
      end
    end
  end

  describe "GET /actors/:username/drafts" do
    it "returns 401 if not authorized" do
      get "/actors/missing/drafts", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/missing/drafts", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/drafts", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/drafts", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/drafts", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/drafts", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/drafts", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/drafts", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      let_create!(
        :object, named: :draft,
        attributed_to: actor,
        local: true
      )

      it "renders the collection" do
        get "/actors/#{actor.username}/drafts", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{draft.id}")
      end

      it "renders the collection" do
        get "/actors/#{actor.username}/drafts", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(draft.iri)
      end
    end
  end

  describe "GET /remote/actors/:id" do
    let_create!(:actor)

    it "returns 401 if not authorized" do
      get "/remote/actors/0", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/remote/actors/0", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if not found" do
        get "/remote/actors/999999", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/remote/actors/999999", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "renders the actor" do
        get "/remote/actors/#{actor.id}", ACCEPT_HTML
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("/html")).not_to be_empty
      end

      it "renders the actor" do
        get "/remote/actors/#{actor.id}", ACCEPT_JSON
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).dig("id")).to be_truthy
      end
    end
  end

  describe "POST /remote/actors/:id/block" do
    let_create!(:actor)

    pre_condition { expect(actor.blocked?).to be_false }

    it "returns 401 if not authorized" do
      post "/remote/actors/0/block"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if not found" do
        post "/remote/actors/999999/block"
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        post "/remote/actors/#{actor.id}/block"
        expect(response.status_code).to eq(302)
      end

      it "blocks the actor" do
        expect{post "/remote/actors/#{actor.id}/block"}.
          to change{actor.reload!.blocked?}
      end
    end
  end

  describe "POST /remote/actors/:id/unblock" do
    let_create!(:actor, blocked_at: Time.utc)

    pre_condition { expect(actor.blocked?).to be_true }

    it "returns 401 if not authorized" do
      post "/remote/actors/0/unblock"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if not found" do
        post "/remote/actors/999999/unblock"
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        post "/remote/actors/#{actor.id}/unblock"
        expect(response.status_code).to eq(302)
      end

      it "unblocks the actor" do
        expect{post "/remote/actors/#{actor.id}/unblock"}.
          to change{actor.reload!.blocked?}
      end
    end
  end

  describe "POST /remote/actors/:id/refresh" do
    let_create!(:actor)

    it "returns 401 if not authorized" do
      post "/remote/actors/0/refresh"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns 404 if not found" do
        post "/remote/actors/999999/refresh"
        expect(response.status_code).to eq(404)
      end

      it "schedules the refresh task" do
        expect{post "/remote/actors/#{actor.id}/refresh"}.
          to change{Task::RefreshActor.find?(actor: actor)}
      end

      it "renders a turbo stream replace message" do
        post "/remote/actors/#{actor.id}/refresh", HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html"}
        expect(XML.parse_html(response.body).xpath_nodes("//turbo-stream[@action='replace']/@target")).to contain_exactly("actor-#{actor.id}-refresh-button")
      end

      it "it succeeds" do
        post "/remote/actors/#{actor.id}/refresh"
        expect(response.status_code).to eq(200)
      end
    end
  end
end
