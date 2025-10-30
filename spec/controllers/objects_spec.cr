require "../../src/controllers/objects"

require "../spec_helper/factory"
require "../spec_helper/controller"
require "../spec_helper/network"

# redefine as public for testing
class ObjectsController
  def self.get_object(env, iri_or_id)
    previous_def(env, iri_or_id)
  end

  def self.get_object_editable(env, iri_or_id)
    previous_def(env, iri_or_id)
  end

  def self.get_object_approvable(env, iri_or_id)
    previous_def(env, iri_or_id)
  end
end

Spectator.describe ObjectsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html, text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}
  FORM_DATA = HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html, text/html", "Content-Type" => "application/x-www-form-urlencoded"}
  JSON_DATA = HTTP::Headers{"Accept" => "application/json", "Content-Type" => "application/json"}

  let(actor) { register.actor }

  let(published) { Time.utc(2025, 1, 1, 12, 0, 0) }

  let_create(
    :actor, named: :author,
    iri: "https://nowhere/actor/#{random_string}",
    username: "author"
  )
  let_create(
    :object, named: :visible,
    attributed_to: author,
    published: published,
    visible: true,
    local: true
  )
  let_create(
    :object, named: :notvisible,
    attributed_to: author,
    published: published,
    visible: false,
    local: true
  )
  let_create(
    :object, named: :remote,
    attributed_to: author,
    published: published,
    visible: false
  )
  let_create(
    :object, named: :draft,
    content: "this is a test",
    attributed_to: actor,
    local: true
  )
  let_create(
    :object, named: :reply,
    in_reply_to: visible,
    attributed_to: actor,
    published: published,
    local: true
  )

  describe ".get_object" do
    let(env) { env_factory("GET", "/") }

    it "returns visible objects" do
      result = ObjectsController.get_object(env, visible.iri)
      expect(result).to eq(visible)
    end

    it "returns nil for non-visible objects" do
      result = ObjectsController.get_object(env, notvisible.iri)
      expect(result).to be_nil
    end

    it "returns nil for draft objects" do
      result = ObjectsController.get_object(env, draft.iri)
      expect(result).to be_nil
    end

    it "returns nil for reply objects" do
      result = ObjectsController.get_object(env, reply.iri)
      expect(result).to be_nil
    end

    context "when authenticated" do
      sign_in

      it "returns visible objects" do
        result = ObjectsController.get_object(env, visible.iri)
        expect(result).to eq(visible)
      end

      it "returns nil for non-visible objects" do
        result = ObjectsController.get_object(env, notvisible.iri)
        expect(result).to be_nil
      end

      it "returns nil for draft objects" do
        result = ObjectsController.get_object(env, draft.iri)
        expect(result).to be_nil
      end

      it "returns nil for reply objects" do
        result = ObjectsController.get_object(env, reply.iri)
        expect(result).to be_nil
      end

      context "and account actor is the object owner" do
        before_each do
          notvisible.assign(attributed_to: Global.account.not_nil!.actor).save
          draft.assign(attributed_to: Global.account.not_nil!.actor).save
          reply.assign(attributed_to: Global.account.not_nil!.actor).save
        end

        it "returns non-visible objects owned by the actor" do
          result = ObjectsController.get_object(env, notvisible.iri)
          expect(result).to eq(notvisible)
        end

        it "returns draft objects owned by the actor" do
          result = ObjectsController.get_object(env, draft.iri)
          expect(result).to eq(draft)
        end

        it "returns reply objects owned by the actor" do
          result = ObjectsController.get_object(env, reply.iri)
          expect(result).to eq(reply)
        end
      end

      context "and object is in account actor's inbox" do
        before_each do
          put_in_inbox(owner: Global.account.not_nil!.actor, object: notvisible)
          put_in_inbox(owner: Global.account.not_nil!.actor, object: draft)
          put_in_inbox(owner: Global.account.not_nil!.actor, object: reply)
        end

        it "returns non-visible objects in the actor's inbox" do
          result = ObjectsController.get_object(env, notvisible.iri)
          expect(result).to eq(notvisible)
        end

        it "returns draft objects in the actor's inbox" do
          result = ObjectsController.get_object(env, draft.iri)
          expect(result).to eq(draft)
        end

        it "returns reply objects in the actor's inbox" do
          result = ObjectsController.get_object(env, reply.iri)
          expect(result).to eq(reply)
        end
      end
    end
  end

  describe ".get_object_editable" do
    let(env) { env_factory("GET", "/") }

    it "returns nil" do
      result = ObjectsController.get_object_editable(env, visible.iri)
      expect(result).to be_nil
    end

    context "when authenticated" do
      sign_in

      it "returns nil for objects not owned by the account actor" do
        result = ObjectsController.get_object_editable(env, visible.iri)
        expect(result).to be_nil
      end

      context "and account actor is the object owner" do
        before_each do
          visible.assign(attributed_to: Global.account.not_nil!.actor).save
          notvisible.assign(attributed_to: Global.account.not_nil!.actor).save
          draft.assign(attributed_to: Global.account.not_nil!.actor).save
        end

        it "returns visible objects" do
          result = ObjectsController.get_object_editable(env, visible.iri)
          expect(result).to eq(visible)
        end

        it "returns non-visible objects" do
          result = ObjectsController.get_object_editable(env, notvisible.iri)
          expect(result).to eq(notvisible)
        end

        it "returns draft objects" do
          result = ObjectsController.get_object_editable(env, draft.iri)
          expect(result).to eq(draft)
        end
      end
    end
  end

  describe ".get_object_approvable" do
    let(env) { env_factory("GET", "/") }

    it "returns nil" do
      result = ObjectsController.get_object_approvable(env, reply.iri)
      expect(result).to be_nil
    end

    context "when authenticated" do
      sign_in

      it "returns nil when user does not own the thread root" do
        result = ObjectsController.get_object_approvable(env, reply.iri)
        expect(result).to be_nil
      end

      context "and user owns the thread root" do
        before_each do
          visible.assign(attributed_to: Global.account.not_nil!.actor).save
        end

        it "returns the reply" do
          result = ObjectsController.get_object_approvable(env, reply.iri)
          expect(result).to eq(reply)
        end

        it "returns nil for objects that are not replies" do
          result = ObjectsController.get_object_approvable(env, visible.iri)
          expect(result).to be_nil
        end
      end
    end
  end

  describe "POST /objects" do
    it "returns 401 if not authorized" do
      post "/objects"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/objects", FORM_DATA, "content="
        expect(response.status_code).to eq(200)
      end

      context "witihout Turbo Streams" do
        let(form_data) { FORM_DATA.dup.tap { |headers| headers["Accept"] = "text/html" } }

        it "redirects" do
          post "/objects", form_data, "content="
          expect(response.status_code).to eq(302)
        end
      end

      it "succeeds" do
        post "/objects", JSON_DATA, %Q|{"content":""}|
        expect(response.status_code).to eq(201)
      end

      it "creates an object" do
        expect{post "/objects", FORM_DATA, "content=foo+bar"}.
          to change{ActivityPub::Object::Note.count(content: "foo bar", attributed_to_iri: actor.iri)}.by(1)
      end

      it "creates an object" do
        expect{post "/objects", JSON_DATA, %Q|{"content":"foo bar"}|}.
          to change{ActivityPub::Object::Note.count(content: "foo bar", attributed_to_iri: actor.iri)}.by(1)
      end

      context "when validation fails" do
        it "returns 422 if validation fails" do
          post "/objects", FORM_DATA, "content=foo+bar&canonical-path=foo%2Fbar"
          expect(response.status_code).to eq(422)
        end

        it "returns 422 if validation fails" do
          post "/objects", JSON_DATA, %Q|{"content":"foo bar","canonical-path":"foo/bar"}|
          expect(response.status_code).to eq(422)
        end

        it "renders an error message" do
          post "/objects", FORM_DATA, "content=foo+bar&canonical-path=foo%2Fbar"
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]")).not_to be_empty
        end

        it "renders an error message" do
          post "/objects", JSON_DATA, %Q|{"content":"foo bar","canonical-path":"foo/bar"}|
          expect(JSON.parse(response.body)["errors"].as_h).not_to be_empty
        end
      end
    end
  end

  describe "GET /objects/:id" do
    it "succeeds" do
      get "/objects/#{visible.uid}", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/objects/#{visible.uid}", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    it "renders the object" do
      get "/objects/#{visible.uid}", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id").first).to eq("object-#{visible.id}")
    end

    it "renders the object" do
      get "/objects/#{visible.uid}", ACCEPT_JSON
      expect(JSON.parse(response.body)["id"]).to eq(visible.iri)
    end

    it "returns 404 if object is a draft" do
      get "/objects/#{draft.uid}"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is not visible" do
      get "/objects/#{notvisible.uid}"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is a reply" do
      get "/objects/#{reply.uid}"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is remote" do
      get "/objects/#{remote.uid}"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object does not exist" do
      get "/objects/000"
      expect(response.status_code).to eq(404)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "redirects if draft" do
        get "/objects/#{draft.uid}"
        expect(response.status_code).to eq(302)
      end

      context "but not the author" do
        before_each { draft.assign(attributed_to: author).save }

        it "returns 404" do
          get "/objects/#{draft.uid}"
          expect(response.status_code).to eq(404)
        end
      end

      context "and it's in the user's inbox" do
        before_each do
          [visible, notvisible, remote].each { |object| put_in_inbox(actor, object) }
        end

        it "succeeds if local" do
          [visible, notvisible].each do |object|
            get "/objects/#{object.uid}", ACCEPT_HTML
            expect(response.status_code).to eq(200)
          end
        end

        it "succeeds if local" do
          [visible, notvisible].each do |object|
            get "/objects/#{object.uid}", ACCEPT_JSON
            expect(response.status_code).to eq(200)
          end
        end

        it "returns 404 if object is remote" do
          get "/objects/#{remote.uid}"
          expect(response.status_code).to eq(404)
        end
      end
    end
  end

  describe "GET /objects/:id/replies" do
    it "succeeds" do
      get "/objects/#{visible.uid}/replies"
      expect(response.status_code).to eq(200)
    end

    it "renders an empty collection" do
      get "/objects/#{visible.uid}/replies"
      expect(JSON.parse(response.body).dig("orderedItems").as_a).to be_empty
    end

    context "with a reply" do
      before_each do
        notvisible.assign(in_reply_to: visible).save
      end

      it "renders an empty collection" do
        get "/objects/#{visible.uid}/replies"
        expect(JSON.parse(response.body).dig("orderedItems").as_a).to be_empty
      end

      context "that is approved" do
        before_each do
          visible.attributed_to.approve(notvisible)
        end

        it "renders an empty collection" do
          get "/objects/#{visible.uid}/replies"
          expect(JSON.parse(response.body).dig("orderedItems").as_a).to be_empty
        end

        context "and is visible" do
          before_each do
            notvisible.assign(visible: true).save
          end

          it "renders the collection" do
            get "/objects/#{visible.uid}/replies"
            expect(JSON.parse(response.body).dig("orderedItems").as_a).to contain_exactly(notvisible.iri)
          end
        end
      end
    end

    it "returns 404 if object is a draft" do
      get "/objects/#{draft.uid}/replies"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is not visible" do
      get "/objects/#{notvisible.uid}/replies"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is a reply" do
      get "/objects/#{reply.uid}/replies"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is remote" do
      get "/objects/#{remote.uid}/replies"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object does not exist" do
      get "/objects/000/replies"
      expect(response.status_code).to eq(404)
    end
  end

  describe "GET /objects/:id/thread" do
    it "succeeds" do
      get "/objects/#{visible.uid}/thread", ACCEPT_HTML
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      get "/objects/#{visible.uid}/thread", ACCEPT_JSON
      expect(response.status_code).to eq(200)
    end

    it "renders the collection" do
      get "/objects/#{visible.uid}/thread", ACCEPT_HTML
      expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{visible.id}")
    end

    it "renders the collection" do
      get "/objects/#{visible.uid}/thread", ACCEPT_JSON
      expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(visible.iri)
    end

    it "returns 404 if object is a draft" do
      get "/objects/#{draft.uid}/thread"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is not visible" do
      get "/objects/#{notvisible.uid}/thread"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is a reply" do
      get "/objects/#{reply.uid}/thread"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is remote" do
      get "/objects/#{remote.uid}/thread"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object does not exist" do
      get "/objects/000/thread"
      expect(response.status_code).to eq(404)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "redirects if draft" do
        get "/objects/#{draft.uid}/thread"
        expect(response.status_code).to eq(302)
      end

      context "but not the author" do
        before_each { draft.assign(attributed_to: author).save }

        it "returns 404" do
          get "/objects/#{draft.uid}/thread"
          expect(response.status_code).to eq(404)
        end
      end

      context "and it's in the user's inbox" do
        before_each do
          [visible, notvisible, remote].each { |object| put_in_inbox(actor, object) }
        end

        it "succeeds if local" do
          [visible, notvisible].each do |object|
            get "/objects/#{object.uid}/thread", ACCEPT_HTML
            expect(response.status_code).to eq(200)
          end
        end

        it "succeeds if local" do
          [visible, notvisible].each do |object|
            get "/objects/#{object.uid}/thread", ACCEPT_JSON
            expect(response.status_code).to eq(200)
          end
        end

        it "returns 404 if object is remote" do
          get "/objects/#{remote.uid}/thread"
          expect(response.status_code).to eq(404)
        end
      end
    end

    context "with a reply" do
      before_each do
        notvisible.assign(in_reply_to: visible).save
      end

      it "renders the collection" do
        get "/objects/#{visible.uid}/thread", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{visible.id}")
      end

      it "renders the collection" do
        get "/objects/#{visible.uid}/thread", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(visible.iri)
      end

      context "that is approved" do
        before_each do
          visible.attributed_to.approve(notvisible)
        end

        it "renders the collection" do
          get "/objects/#{visible.uid}/thread", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{visible.id}")
        end

        it "renders the collection" do
          get "/objects/#{visible.uid}/thread", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(visible.iri)
        end

        context "and is visible" do
          before_each do
            notvisible.assign(visible: true).save
          end

          it "renders the collection" do
            get "/objects/#{visible.uid}/thread", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{visible.id}", "object-#{notvisible.id}")
          end

          it "renders the collection" do
            get "/objects/#{visible.uid}/thread", ACCEPT_JSON
            expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(visible.iri, notvisible.iri)
          end
        end
      end
    end
  end

  describe "GET /objects/:id/edit" do
    it "returns 401 if not authorized" do
      get "/objects/0/edit"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      context "given a draft post" do
        it "succeeds" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(response.status_code).to eq(200)
        end

        it "succeeds" do
          get "/objects/#{draft.uid}/edit", ACCEPT_JSON
          expect(response.status_code).to eq(200)
        end

        it "renders a form with the object" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form/@id").first).to eq("object-#{draft.id}")
        end

        it "renders a button that submits to the outbox path" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//button[contains(text(),'Publish')]/@formaction").first).to eq("/actors/#{actor.username}/outbox")
        end

        it "renders a button that submits to the object update path" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//button[contains(text(),'Update')]/@formaction").first).to eq("/objects/#{draft.uid}")
        end

        it "renders a textarea with the draft content" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form//textarea[@name='content']/text()").first).to eq("this is a test")
        end

        it "renders the content" do
          get "/objects/#{draft.uid}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["content"]).to eq("this is a test")
        end

        context "with a name" do
          before_each { draft.assign(name: "foo bar baz").save }

          it "renders an input with the name" do
            get "/objects/#{draft.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='name']/@value").first).to eq("foo bar baz")
          end

          it "renders the name" do
            get "/objects/#{draft.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["name"]).to eq("foo bar baz")
          end
        end

        context "with a summary" do
          before_each { draft.assign(summary: "foo bar baz").save }

          it "renders a textarea with the summary" do
            get "/objects/#{draft.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//textarea[@name='summary']/text()").first).to eq("foo bar baz")
          end

          it "renders the summary" do
            get "/objects/#{draft.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["summary"]).to eq("foo bar baz")
          end
        end

        context "with a canonical path" do
          before_each { draft.assign(canonical_path: "/foo/bar/baz").save }

          it "renders an input with the canonical path" do
            get "/objects/#{draft.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='canonical-path']/@value").first).to eq("/foo/bar/baz")
          end

          it "renders the canonical path" do
            get "/objects/#{draft.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["canonical_path"]).to eq("/foo/bar/baz")
          end
        end
      end

      context "given a published post" do
        before_each do
          visible.assign(
            attributed_to: actor,
            content: "foo bar baz"
          ).save
        end

        it "succeeds" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(response.status_code).to eq(200)
        end

        it "succeeds" do
          get "/objects/#{visible.uid}/edit", ACCEPT_JSON
          expect(response.status_code).to eq(200)
        end

        it "renders a form with the object" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form/@id").first).to eq("object-#{visible.id}")
        end

        it "renders a button that submits to the outbox path" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//button[contains(text(),'Update')]/@formaction").first).to eq("/actors/#{actor.username}/outbox")
        end

        it "does not render a button that submits to the object update path" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//input[contains(@value,'Save')]/@formaction")).to be_empty
        end

        it "renders a textarea with the content" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form//textarea[@name='content']/text()").first).to eq("foo bar baz")
        end

        it "renders the content" do
          get "/objects/#{visible.uid}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["content"]).to eq("foo bar baz")
        end

        context "with a name" do
          before_each { visible.assign(name: "foo bar baz").save }

          it "renders an input with the name" do
            get "/objects/#{visible.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='name']/@value").first).to eq("foo bar baz")
          end

          it "renders the name" do
            get "/objects/#{visible.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["name"]).to eq("foo bar baz")
          end
        end

        context "with a summary" do
          before_each { visible.assign(summary: "foo bar baz").save }

          it "renders a textarea with the summary" do
            get "/objects/#{visible.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//textarea[@name='summary']/text()").first).to eq("foo bar baz")
          end

          it "renders the summary" do
            get "/objects/#{visible.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["summary"]).to eq("foo bar baz")
          end
        end

        context "with a canonical path" do
          before_each { visible.assign(canonical_path: "/foo/bar/baz").save }

          it "renders an input with the canonical path" do
            get "/objects/#{visible.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='canonical-path']/@value").first).to eq("/foo/bar/baz")
          end

          it "renders the canonical path" do
            get "/objects/#{visible.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["canonical_path"]).to eq("/foo/bar/baz")
          end
        end
      end

      it "returns 404 if not attributed to actor" do
        [visible, notvisible, remote].each do |object|
          get "/objects/#{object.uid}/edit"
          expect(response.status_code).to eq(404)
        end
      end

      it "returns 404 if object does not exist" do
        get "/objects/000/edit"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /objects/:id" do
    it "returns 401 if not authorized" do
      post "/objects/0"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/objects/#{draft.uid}", FORM_DATA, "content="
        expect(response.status_code).to eq(200)
      end

      context "witihout Turbo Streams" do
        let(form_data) { FORM_DATA.dup.tap { |headers| headers["Accept"] = "text/html" } }

        it "redirects" do
          post "/objects/#{draft.uid}", form_data, "content="
          expect(response.status_code).to eq(302)
        end
      end

      it "succeeds" do
        post "/objects/#{draft.uid}", JSON_DATA, %Q|{"content":""}|
        expect(response.status_code).to eq(200)
      end

      it "changes the content" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "content=foo+bar"}.
          to change{draft.reload!.content}
      end

      it "changes the content" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"content":"foo bar"}|}.
          to change{draft.reload!.content}
      end

      it "updates the language" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "language=fr"}.
          to change{draft.reload!.language}.to("fr")
      end

      it "updates the language" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"language":"fr"}|}.
          to change{draft.reload!.language}.to("fr")
      end

      it "updates the name" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "name=foo+bar"}.
          to change{draft.reload!.name}
      end

      it "updates the name" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"name":"foo bar"}|}.
          to change{draft.reload!.name}
      end

      it "updates the summary" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "summary=foo+bar"}.
          to change{draft.reload!.summary}
      end

      it "updates the summary" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"summary":"foo bar"}|}.
          to change{draft.reload!.summary}
      end

      it "updates the canonical path" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "canonical-path=%2Ffoo%2Fbar"}.
          to change{draft.reload!.canonical_path}
      end

      it "updates the canonical path" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"canonical-path":"/foo/bar"}|}.
          to change{draft.reload!.canonical_path}
      end

      context "when validation fails" do
        it "returns 422 if validation fails" do
          post "/objects/#{draft.uid}", FORM_DATA, "canonical-path=foo%2Fbar"
          expect(response.status_code).to eq(422)
        end

        it "returns 422 if validation fails" do
          post "/objects/#{draft.uid}", JSON_DATA, %Q|{"canonical-path":"foo/bar"}|
          expect(response.status_code).to eq(422)
        end

        it "renders an error message" do
          post "/objects/#{draft.uid}", FORM_DATA, "canonical-path=foo%2Fbar"
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]")).not_to be_empty
        end

        it "renders an error message" do
          post "/objects/#{draft.uid}", JSON_DATA, %Q|{"canonical-path":"foo/bar"}|
          expect(JSON.parse(response.body)["errors"].as_h).not_to be_empty
        end
      end

      it "returns 404 if not a draft" do
        [visible, notvisible, remote].each do |object|
          post "/objects/#{object.uid}"
          expect(response.status_code).to eq(404)
        end
      end

      it "returns 404 if object does not exist" do
        post "/objects/000"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "DELETE /objects/:id" do
    it "returns 401 if not authorized" do
      delete "/objects/0"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        delete "/objects/#{draft.uid}", FORM_DATA
        expect(response.status_code).to eq(302)
      end

      it "succeeds" do
        delete "/objects/#{draft.uid}", JSON_DATA
        expect(response.status_code).to eq(302)
      end

      it "deletes the object" do
        expect{delete "/objects/#{draft.uid}", FORM_DATA}.
          to change{ActivityPub::Object.count(id: draft.id)}.by(-1)
      end

      it "deletes the object" do
        expect{delete "/objects/#{draft.uid}", JSON_DATA}.
          to change{ActivityPub::Object.count(id: draft.id)}.by(-1)
      end

      it "returns 404 if not a draft" do
        [visible, notvisible, remote].each do |object|
          delete "/objects/#{object.uid}"
          expect(response.status_code).to eq(404)
        end
      end

      it "returns 404 if object does not exist" do
        delete "/objects/000"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "GET /remote/objects/:id" do
    it "returns 401 if not authorized" do
      get "/remote/objects/0"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        get "/remote/objects/#{visible.id}", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/remote/objects/#{visible.id}", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the object" do
        get "/remote/objects/#{visible.id}", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id").first).to eq("object-#{visible.id}")
      end

      it "renders the object" do
        get "/remote/objects/#{visible.id}", ACCEPT_JSON
        expect(JSON.parse(response.body)["id"]).to eq(visible.iri)
      end

      it "returns 404 if object is not visible" do
        get "/remote/objects/#{notvisible.id}"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is remote" do
        get "/remote/objects/#{remote.id}"
        expect(response.status_code).to eq(404)
      end

      context "if remote object is visible" do
        before_each { remote.assign(visible: true).save }

        it "succeeds" do
          get "/remote/objects/#{remote.id}"
          expect(response.status_code).to eq(200)
        end
      end

      it "returns 404 if object does not exist" do
        get "/remote/objects/0"
        expect(response.status_code).to eq(404)
      end

      context "and it's in the user's inbox" do
        before_each do
          [visible, notvisible, remote].each { |object| put_in_inbox(actor, object) }
        end

        it "succeeds" do
          [visible, notvisible, remote].each do |object|
            get "/remote/objects/#{object.id}", ACCEPT_HTML
            expect(response.status_code).to eq(200)
          end
        end

        it "succeeds" do
          [visible, notvisible, remote].each do |object|
            get "/remote/objects/#{object.id}", ACCEPT_JSON
            expect(response.status_code).to eq(200)
          end
        end
      end
    end
  end

  describe "GET /remote/objects/:id/thread" do
    it "returns 401" do
      get "/remote/objects/0/thread"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        get "/remote/objects/#{visible.id}/thread", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/remote/objects/#{visible.id}/thread", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the collection" do
        get "/remote/objects/#{visible.id}/thread", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{visible.id}")
      end

      it "renders the collection" do
        get "/remote/objects/#{visible.id}/thread", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(visible.iri)
      end

      it "returns 404 if object is not visible" do
        get "/remote/objects/#{notvisible.id}/thread"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is remote" do
        get "/remote/objects/#{remote.id}/thread"
        expect(response.status_code).to eq(404)
      end

      context "if remote object is visible" do
        before_each { remote.assign(visible: true).save }

        it "succeeds" do
          get "/remote/objects/#{remote.id}"
          expect(response.status_code).to eq(200)
        end
      end

      it "returns 404 if object is draft" do
        get "/remote/objects/#{draft.id}/thread"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        get "/remote/objects/0/thread"
        expect(response.status_code).to eq(404)
      end

      context "and it's in the user's inbox" do
        before_each do
          [visible, notvisible, remote].each { |object| put_in_inbox(actor, object) }
        end

        it "succeeds" do
          [visible, notvisible, remote].each do |object|
            get "/remote/objects/#{object.id}/thread", ACCEPT_HTML
            expect(response.status_code).to eq(200)
          end
        end

        it "succeeds" do
          [visible, notvisible, remote].each do |object|
            get "/remote/objects/#{object.id}/thread", ACCEPT_JSON
            expect(response.status_code).to eq(200)
          end
        end
      end

      context "with replies" do
        before_each do
          notvisible.assign(in_reply_to: visible).save
        end

        it "renders the collection" do
          get "/remote/objects/#{visible.id}/thread", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{visible.id}", "object-#{notvisible.id}")
        end

        it "renders the collection" do
          get "/remote/objects/#{visible.id}/thread", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("items").as_a.map(&.dig("id"))).to contain_exactly(visible.iri, notvisible.iri)
        end
      end
    end
  end

  describe "GET /remote/objects/:id/reply" do
    it "returns 401" do
      get "/remote/objects/0/reply"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        get "/remote/objects/#{visible.id}/reply"
        expect(response.status_code).to eq(200)
      end

      it "renders the object" do
        get "/remote/objects/#{visible.id}/reply", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id").first).to eq("object-#{visible.id}")
      end

      it "renders the form" do
        get "/remote/objects/#{visible.id}/reply", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//trix-editor")).not_to be_empty
      end

      let_build(:actor, named: :other, iri: "https://nowhere/", username: "other")
      let_build(:object, named: :parent, attributed_to: other)

      it "prepopulates editor with mentions" do
        get "/remote/objects/#{visible.id}/reply", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//form//textarea[@name='content']/text()").first).to eq("@author@nowhere ")
      end

      it "returns 404 if object is not visible" do
        get "/remote/objects/#{notvisible.id}/reply"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is remote" do
        get "/remote/objects/#{remote.id}/reply"
        expect(response.status_code).to eq(404)
      end

      context "if remote object is visible" do
        before_each { remote.assign(visible: true).save }

        it "succeeds" do
          get "/remote/objects/#{remote.id}"
          expect(response.status_code).to eq(200)
        end
      end

      it "returns 404 if object is draft" do
        get "/remote/objects/#{draft.id}/reply"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        get "/remote/objects/0/reply"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/approve" do
    it "returns 401" do
      post "/remote/objects/0/approve"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      before_each do
        visible.assign(attributed_to: actor).save
        actor.unapprove(reply)
      end

      it "succeeds" do
        post "/remote/objects/#{reply.id}/approve"
        expect(response.status_code).to eq(302)
      end

      it "approves the object" do
        expect{post "/remote/objects/#{reply.id}/approve"}.
          to change{reply.approved_by?(actor)}
      end

      context "but it's already approved" do
        before_each { actor.approve(reply) }

        it "returns 400" do
          post "/remote/objects/#{reply.id}/approve"
          expect(response.status_code).to eq(400)
        end
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/0/approve"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is not a reply" do
        post "/remote/objects/#{visible.id}/approve"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 when user does not own the thread root" do
        post "/remote/objects/#{remote.id}/approve"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/unapprove" do
    it "returns 401" do
      post "/remote/objects/0/unapprove"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      before_each do
        visible.assign(attributed_to: actor).save
        actor.approve(reply)
      end

      it "succeeds" do
        post "/remote/objects/#{reply.id}/unapprove"
        expect(response.status_code).to eq(302)
      end

      it "unapproves the object" do
        expect{post "/remote/objects/#{reply.id}/unapprove"}.
          to change{reply.approved_by?(actor)}
      end

      context "but it's already unapproved" do
        before_each { actor.unapprove(reply) }

        it "returns 400" do
          post "/remote/objects/#{reply.id}/unapprove"
          expect(response.status_code).to eq(400)
        end
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/0/unapprove"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is not a reply" do
        post "/remote/objects/#{visible.id}/unapprove"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 when user does not own the thread root" do
        post "/remote/objects/#{remote.id}/unapprove"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/block" do
    before_each { remote.assign(blocked_at: nil).save }

    it "returns 401" do
      post "/remote/objects/0/block"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/remote/objects/#{remote.id}/block"
        expect(response.status_code).to eq(302)
      end

      it "blocks the object" do
        expect{post "/remote/objects/#{remote.id}/block"}.
          to change{remote.reload!.blocked?}
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/block"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/unblock" do
    before_each { remote.assign(blocked_at: Time.utc).save }

    it "returns 401" do
      post "/remote/objects/0/unblock"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/remote/objects/#{remote.id}/unblock"
        expect(response.status_code).to eq(302)
      end

      it "unblocks the object" do
        expect{post "/remote/objects/#{remote.id}/unblock"}.
          to change{remote.reload!.blocked?}
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/unblock"
        expect(response.status_code).to eq(404)
      end
    end
  end

  let(body) { XML.parse_html(response.body) }

  TURBO_FRAME = HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "thread_page_thread_controls"}

  describe "POST /remote/objects/:id/follow" do
    it "returns 401" do
      post "/remote/objects/0/follow"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/remote/objects/#{visible.id}/follow"
        expect(response.status_code).to eq(302)
      end

      it "follows the thread" do
        post "/remote/objects/#{visible.id}/follow"
        expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to contain_exactly(visible.iri)
      end

      it "begins fetching the thread" do
        post "/remote/objects/#{visible.id}/follow"
        expect(Task::Fetch::Thread.all.map(&.thread)).to contain_exactly(visible.iri)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/remote/objects/#{visible.id}/follow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end
      end

      context "given a reply" do
        let_create!(:object, named: :reply, in_reply_to: visible)

        before_each { put_in_inbox(owner: actor, object: reply) }

        it "succeeds" do
          post "/remote/objects/#{reply.id}/follow"
          expect(response.status_code).to eq(302)
        end

        it "follows the thread" do
          post "/remote/objects/#{reply.id}/follow"
          expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to contain_exactly(visible.iri)
        end

        it "begins fetching the thread" do
          post "/remote/objects/#{reply.id}/follow"
          expect(Task::Fetch::Thread.all.map(&.thread)).to contain_exactly(visible.iri)
        end
      end

      context "given an existing follow and fetch" do
        let_create!(:follow_thread_relationship, actor: actor, thread: visible.thread)
        let_create!(:fetch_thread_task, source: actor, thread: visible.thread)

        it "succeeds" do
          post "/remote/objects/#{visible.id}/follow"
          expect(response.status_code).to eq(302)
        end

        it "does not change the count of follow relationships" do
          expect{post "/remote/objects/#{visible.id}/follow"}.
            not_to change{Relationship::Content::Follow::Thread.count(thread: visible.iri)}
        end

        it "does not change the count of fetch tasks" do
          expect{post "/remote/objects/#{visible.id}/follow"}.
            not_to change{Task::Fetch::Thread.count(thread: visible.iri)}
        end

        context "where the fetch is complete but has failed" do
          before_each { fetch_thread_task.assign(complete: true, backtrace: ["error"]).save }

          it "clears the backtrace" do
            expect{post "/remote/objects/#{visible.id}/follow"}.to change{fetch_thread_task.reload!.backtrace}.to(nil)
          end
        end
      end

      it "returns 404 if object is draft" do
        post "/remote/objects/#{draft.id}/follow"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/follow"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/unfollow" do
    it "returns 401" do
      post "/remote/objects/0/unfollow"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/remote/objects/#{visible.id}/unfollow"
        expect(response.status_code).to eq(302)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/remote/objects/#{visible.id}/unfollow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end
      end

      context "given a follow and fetch" do
        let_create(:object, named: :reply, in_reply_to: visible)
        let_create!(:follow_thread_relationship, actor: actor, thread: reply.thread)
        let_create!(:fetch_thread_task, source: actor, thread: reply.thread)

        it "succeeds" do
          post "/remote/objects/#{visible.id}/unfollow"
          expect(response.status_code).to eq(302)
        end

        it "unfollows the thread" do
          post "/remote/objects/#{visible.id}/unfollow"
          expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to be_empty
        end

        it "stops fetching the thread" do
          post "/remote/objects/#{visible.id}/unfollow"
          expect(Task::Fetch::Thread.where(complete: true).map(&.thread)).to contain_exactly(visible.iri)
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/remote/objects/#{visible.id}/unfollow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end
        end

        context "given a reply" do
          let_create!(:object, named: :reply, in_reply_to: visible)

          before_each { put_in_inbox(owner: actor, object: reply) }

          it "succeeds" do
            post "/remote/objects/#{reply.id}/unfollow"
            expect(response.status_code).to eq(302)
          end

          it "unfollows the root object of the thread" do
            post "/remote/objects/#{reply.id}/unfollow"
            expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to be_empty
          end

          it "stops fetching the root object of the thread" do
            post "/remote/objects/#{reply.id}/unfollow"
            expect(Task::Fetch::Thread.where(complete: true).map(&.thread)).to contain_exactly(visible.iri)
          end

          context "within a turbo-frame" do
            it "succeeds" do
              post "/remote/objects/#{reply.id}/unfollow", TURBO_FRAME
              expect(response.status_code).to eq(200)
            end
          end
        end
      end

      it "returns 404 if object is draft" do
        post "/remote/objects/#{draft.id}/unfollow"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/unfollow"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/fetch/start" do
    it "returns 401" do
      post "/remote/objects/0/fetch/start"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/remote/objects/#{visible.id}/fetch/start"
        expect(response.status_code).to eq(302)
      end

      it "does not follow the thread" do
        post "/remote/objects/#{visible.id}/fetch/start"
        expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to be_empty
      end

      it "begins fetching the thread" do
        post "/remote/objects/#{visible.id}/fetch/start"
        expect(Task::Fetch::Thread.all.map(&.thread)).to contain_exactly(visible.iri)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/remote/objects/#{visible.id}/fetch/start", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end
      end

      context "given a reply" do
        let_create!(:object, named: :reply, in_reply_to: visible)

        before_each { put_in_inbox(owner: actor, object: reply) }

        it "succeeds" do
          post "/remote/objects/#{reply.id}/fetch/start"
          expect(response.status_code).to eq(302)
        end

        it "does not follow the thread" do
          post "/remote/objects/#{reply.id}/fetch/start"
          expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to be_empty
        end

        it "begins fetching the thread" do
          post "/remote/objects/#{reply.id}/fetch/start"
          expect(Task::Fetch::Thread.all.map(&.thread)).to contain_exactly(visible.iri)
        end
      end

      context "given an existing follow and fetch" do
        let_create!(:follow_thread_relationship, actor: actor, thread: visible.thread)
        let_create!(:fetch_thread_task, source: actor, thread: visible.thread)

        it "succeeds" do
          post "/remote/objects/#{visible.id}/fetch/start"
          expect(response.status_code).to eq(302)
        end

        it "does not change the count of follow relationships" do
          expect{post "/remote/objects/#{visible.id}/fetch/start"}.
            not_to change{Relationship::Content::Follow::Thread.count(thread: visible.iri)}
        end

        it "does not change the count of fetch tasks" do
          expect{post "/remote/objects/#{visible.id}/fetch/start"}.
            not_to change{Task::Fetch::Thread.count(thread: visible.iri)}
        end

        context "where the fetch is complete but has failed" do
          before_each { fetch_thread_task.assign(complete: true, backtrace: ["error"]).save }

          it "clears the backtrace" do
            expect{post "/remote/objects/#{visible.id}/fetch/start"}.to change{fetch_thread_task.reload!.backtrace}.to(nil)
          end
        end
      end

      it "returns 404 if object is draft" do
        post "/remote/objects/#{draft.id}/fetch/start"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/fetch/start"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/fetch/cancel" do
    it "returns 401" do
      post "/remote/objects/0/fetch/cancel"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/remote/objects/#{visible.id}/fetch/cancel"
        expect(response.status_code).to eq(302)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/remote/objects/#{visible.id}/fetch/cancel", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end
      end

      context "given a follow and fetch" do
        let_create(:object, named: :reply, in_reply_to: visible)
        let_create!(:follow_thread_relationship, actor: actor, thread: reply.thread)
        let_create!(:fetch_thread_task, source: actor, thread: reply.thread)

        it "succeeds" do
          post "/remote/objects/#{visible.id}/fetch/cancel"
          expect(response.status_code).to eq(302)
        end

        it "does not unfollow the thread" do
          post "/remote/objects/#{visible.id}/fetch/cancel"
          expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to contain_exactly(reply.thread)
        end

        it "stops fetching the thread" do
          post "/remote/objects/#{visible.id}/fetch/cancel"
          expect(Task::Fetch::Thread.where(complete: true).map(&.thread)).to contain_exactly(reply.thread)
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/remote/objects/#{visible.id}/fetch/cancel", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end
        end

        context "given a reply" do
          let_create!(:object, named: :reply, in_reply_to: visible)

          before_each { put_in_inbox(owner: actor, object: reply) }

          it "succeeds" do
            post "/remote/objects/#{reply.id}/fetch/cancel"
            expect(response.status_code).to eq(302)
          end

          it "does not unfollow the root object of the thread" do
            post "/remote/objects/#{reply.id}/fetch/cancel"
            expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to contain_exactly(visible.thread)
          end

          it "stops fetching the root object of the thread" do
            post "/remote/objects/#{reply.id}/fetch/cancel"
            expect(Task::Fetch::Thread.where(complete: true).map(&.thread)).to contain_exactly(visible.iri)
          end

          context "within a turbo-frame" do
            it "succeeds" do
              post "/remote/objects/#{reply.id}/fetch/cancel", TURBO_FRAME
              expect(response.status_code).to eq(200)
            end
          end
        end

        it "returns 404 if object is draft" do
          post "/remote/objects/#{draft.id}/fetch/cancel"
          expect(response.status_code).to eq(404)
        end

        it "returns 404 if object does not exist" do
          post "/remote/objects/999999/fetch/cancel"
          expect(response.status_code).to eq(404)
        end
      end
    end
  end

  def_mock Ktistec::Translator

  describe "POST /remote/objects/:id/translation/create" do
    it "returns 401" do
      post "/remote/objects/0/translation/create"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      before_each { put_in_inbox(owner: actor, object: remote) }

      it "succeeds" do
        post "/remote/objects/#{remote.id}/translation/create"
        expect(response.status_code).to eq(302)
      end

      it "does not create a translation" do
        expect{post "/remote/objects/#{remote.id}/translation/create"}.
          not_to change{remote.reload!.translations.size}
      end

      context "given a translator" do
        let(translator) do
          mock(Ktistec::Translator).tap do |translator|
            allow(translator).to receive(:translate).and_return({name: "name", summary: "zusammenfassung", content: "inhalt"})
          end
        end

        before_each { ::Ktistec.set_translator(translator) }
        after_each { ::Ktistec.clear_translator }

        it "does not create a translation" do
          expect{post "/remote/objects/#{remote.id}/translation/create"}.
            not_to change{remote.reload!.translations.size}
        end

        context "and an account and an object with the same primary language" do
          before_each do
            Global.account.not_nil!.assign(language: "en-US").save
            remote.assign(language: "en-GB").save
          end

          it "does not create a translation" do
            expect{post "/remote/objects/#{remote.id}/translation/create"}.
              not_to change{remote.reload!.translations.size}
          end
        end

        context "and an account and an object with different languages" do
          before_each do
            Global.account.not_nil!.assign(language: "de").save
            remote.assign(language: "en").save
          end

          it "creates a translation" do
            expect{post "/remote/objects/#{remote.id}/translation/create"}.
              to change{remote.reload!.translations.size}.by(1)
          end
        end
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/translation/create"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "POST /remote/objects/:id/translation/clear" do
    let_create!(:translation, origin: remote)

    it "returns 401" do
      post "/remote/objects/0/translation/clear"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      before_each { put_in_inbox(owner: actor, object: remote) }

      it "succeeds" do
        post "/remote/objects/#{remote.id}/translation/clear"
        expect(response.status_code).to eq(302)
      end

      it "destroys the translation" do
        expect{post "/remote/objects/#{remote.id}/translation/clear"}.
          to change{remote.reload!.translations.size}.by(-1)
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/999999/translation/clear"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
