require "../../src/controllers/objects"

require "../spec_helper/factory"
require "../spec_helper/controller"
require "../spec_helper/network"

Spectator.describe ObjectsController do
  setup_spec

  let(actor) { register.actor }

  let_create(
    :actor, named: :author,
    iri: "https://nowhere/actor/#{random_string}",
    username: "author"
  )
  let_create(
    :object, named: :visible,
    attributed_to: author,
    published: Time.utc,
    visible: true,
    local: true
  )
  let_create(
    :object, named: :notvisible,
    attributed_to: author,
    published: Time.utc,
    visible: false,
    local: true
  )
  let_create(
    :object, named: :remote,
    attributed_to: author,
    published: Time.utc,
    visible: false
  )
  let_create(
    :object, named: :draft,
    content: "this is a test",
    attributed_to: actor,
    local: true
  )

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html, text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}
  FORM_DATA = HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html, text/html", "Content-Type" => "application/x-www-form-urlencoded"}
  JSON_DATA = HTTP::Headers{"Accept" => "application/json", "Content-Type" => "application/json"}

  describe "POST /objects" do
    it "returns 401 if not authorized" do
      post "/objects"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        post "/objects", FORM_DATA, "content="
        expect(response.status_code).to eq(302)
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
          post "/objects", FORM_DATA, "content=foo+bar&canonical_path=foo%2Fbar"
          expect(response.status_code).to eq(422)
        end

        it "returns 422 if validation fails" do
          post "/objects", JSON_DATA, %Q|{"content":"foo bar","canonical_path":"foo/bar"}|
          expect(response.status_code).to eq(422)
        end

        it "renders a form with the object" do
          post "/objects", FORM_DATA, "content=foo+bar&canonical_path=foo%2Fbar"
          expect(XML.parse_html(response.body).xpath_nodes("//form/@id").first).to eq("object-new")
        end

        it "renders the object" do
          post "/objects", JSON_DATA, %Q|{"content":"foo bar","canonical_path":"foo/bar"}|
          expect(JSON.parse(response.body)["id"]).to be_truthy
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

      it "renders the collection" do
        get "/objects/#{visible.uid}/replies"
        expect(JSON.parse(response.body).dig("orderedItems").as_a).to contain_exactly(notvisible.iri)
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

    context "with replies" do
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

      context "that are approved" do
        before_each do
          visible.attributed_to.approve(notvisible)
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
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//input[contains(@value,'Publish')]/@action").first).to eq("/actors/#{actor.username}/outbox")
        end

        it "renders a button that submits to the object update path" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//input[contains(@value,'Save')]/@action").first).to eq("/objects/#{draft.uid}")
        end

        it "renders an input with the draft content" do
          get "/objects/#{draft.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='content']/@value").first).to eq("this is a test")
        end

        it "renders the content" do
          get "/objects/#{draft.uid}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["content"]).to eq("this is a test")
        end

        context "with a canonical path" do
          before_each { draft.assign(canonical_path: "/foo/bar/baz").save }

          it "renders an input with the canonical path" do
            get "/objects/#{draft.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='canonical_path']/@value").first).to eq("/foo/bar/baz")
          end

          it "renders the canonical path as URL" do
            get "/objects/#{draft.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["url"]).to eq(["#{Ktistec.host}/foo/bar/baz"])
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
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//input[contains(@value,'Update')]/@action").first).to eq("/actors/#{actor.username}/outbox")
        end

        it "does not render a button that submits to the object update path" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form[@id]//input[contains(@value,'Save')]/@action")).to be_empty
        end

        it "renders an input with the content" do
          get "/objects/#{visible.uid}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='content']/@value").first).to eq("foo bar baz")
        end

        it "renders the content" do
          get "/objects/#{visible.uid}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["content"]).to eq("foo bar baz")
        end

        context "with a canonical path" do
          before_each { visible.assign(canonical_path: "/foo/bar/baz").save }

          it "renders an input with the canonical path" do
            get "/objects/#{visible.uid}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='canonical_path']/@value").first).to eq("/foo/bar/baz")
          end

          it "renders the canonical path as URL" do
            get "/objects/#{visible.uid}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["url"]).to eq(["#{Ktistec.host}/foo/bar/baz"])
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
        expect(response.status_code).to eq(302)
      end

      it "succeeds" do
        post "/objects/#{draft.uid}", JSON_DATA, %Q|{"content":""}|
        expect(response.status_code).to eq(302)
      end

      it "changes the content" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "content=foo+bar"}.
          to change{draft.reload!.content}
      end

      it "changes the content" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"content":"foo bar"}|}.
          to change{draft.reload!.content}
      end

      it "updates the canonical path" do
        expect{post "/objects/#{draft.uid}", FORM_DATA, "canonical_path=%2Ffoo%2Fbar"}.
          to change{draft.reload!.canonical_path}
      end

      it "updates the canonical path" do
        expect{post "/objects/#{draft.uid}", JSON_DATA, %Q|{"canonical_path":"/foo/bar"}|}.
          to change{draft.reload!.canonical_path}
      end

      context "when validation fails" do
        it "returns 422 if validation fails" do
          post "/objects/#{draft.uid}", FORM_DATA, "canonical_path=foo%2Fbar"
          expect(response.status_code).to eq(422)
        end

        it "returns 422 if validation fails" do
          post "/objects/#{draft.uid}", JSON_DATA, %Q|{"canonical_path":"foo/bar"}|
          expect(response.status_code).to eq(422)
        end

        it "renders a form with the object" do
          post "/objects/#{draft.uid}", FORM_DATA, "canonical_path=foo%2Fbar"
          expect(XML.parse_html(response.body).xpath_nodes("//form/@id").first).to eq("object-#{draft.id}")
        end

        it "renders the object" do
          post "/objects/#{draft.uid}", JSON_DATA, %Q|{"canonical_path":"foo/bar"}|
          expect(JSON.parse(response.body)["id"]).to eq(draft.iri)
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

      it "returns 404 if object is a draft" do
        get "/remote/objects/#{draft.id}"
        expect(response.status_code).to eq(404)
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

      it "returns 404 if object is a draft" do
        get "/remote/objects/#{draft.id}/thread"
        expect(response.status_code).to eq(404)
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

      before_each do
        visible.assign(in_reply_to: parent).save
      end

      it "prepopulates editor with mentions" do
        get "/remote/objects/#{visible.id}/reply", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='content']/@value").first).to eq("@author@nowhere @other@nowhere ")
      end

      it "returns 404 if object is a draft" do
        get "/remote/objects/#{draft.id}/reply"
        expect(response.status_code).to eq(404)
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

      before_each { actor.unapprove(remote) }

      it "succeeds" do
        post "/remote/objects/#{remote.id}/approve"
        expect(response.status_code).to eq(302)
      end

      it "approves the object" do
        expect{post "/remote/objects/#{remote.id}/approve"}.
          to change{remote.approved_by?(actor)}
      end

      context "but it's already approved" do
        before_each { actor.approve(remote) }

        it "returns 400" do
          post "/remote/objects/#{remote.id}/approve"
          expect(response.status_code).to eq(400)
        end
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/0/approve"
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

      before_each { actor.approve(remote) }

      it "succeeds" do
        post "/remote/objects/#{remote.id}/unapprove"
        expect(response.status_code).to eq(302)
      end

      it "unapproves the object" do
        expect{post "/remote/objects/#{remote.id}/unapprove"}.
          to change{remote.approved_by?(actor)}
      end

      context "but it's already unapproved" do
        before_each { actor.unapprove(remote) }

        it "returns 400" do
          post "/remote/objects/#{remote.id}/unapprove"
          expect(response.status_code).to eq(400)
        end
      end

      it "returns 404 if object does not exist" do
        post "/remote/objects/0/unapprove"
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
        post "/remote/objects/#{remote.id}/follow"
        expect(response.status_code).to eq(302)
      end

      it "follows the thread" do
        post "/remote/objects/#{remote.id}/follow"
        expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to contain_exactly(remote.iri)
      end

      it "begins fetching the thread" do
        post "/remote/objects/#{remote.id}/follow"
        expect(Task::Fetch::Thread.all.map(&.thread)).to contain_exactly(remote.iri)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/remote/objects/#{remote.id}/follow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders an unfollow button" do
          post "/remote/objects/#{remote.id}/follow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='thread_page_thread_controls']//button")).to have("Unfollow")
        end
      end

      context "given a reply" do
        let_create!(:object, named: :reply, in_reply_to: remote)

        it "succeeds" do
          post "/remote/objects/#{reply.id}/follow"
          expect(response.status_code).to eq(302)
        end

        it "follows the thread" do
          post "/remote/objects/#{reply.id}/follow"
          expect(Relationship::Content::Follow::Thread.all.map(&.thread)).to contain_exactly(remote.iri)
        end

        it "begins fetching the thread" do
          post "/remote/objects/#{reply.id}/follow"
          expect(Task::Fetch::Thread.all.map(&.thread)).to contain_exactly(remote.iri)
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/remote/objects/#{reply.id}/follow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders an unfollow button" do
            post "/remote/objects/#{reply.id}/follow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='thread_page_thread_controls']//button")).to have("Unfollow")
          end
        end
      end

      context "given an existing follow and fetch" do
        let_create!(:follow_thread_relationship, actor: actor, thread: remote.thread)
        let_create!(:fetch_thread_task, source: actor, thread: remote.thread)

        it "succeeds" do
          post "/remote/objects/#{remote.id}/follow"
          expect(response.status_code).to eq(302)
        end

        it "does not change the count of follow relationships" do
          expect{post "/remote/objects/#{remote.id}/follow"}.
            not_to change{Relationship::Content::Follow::Thread.count(thread: remote.iri)}
        end

        it "does not change the count of fetch tasks" do
          expect{post "/remote/objects/#{remote.id}/follow"}.
            not_to change{Task::Fetch::Thread.count(thread: remote.iri)}
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/remote/objects/#{remote.id}/follow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders an unfollow button" do
            post "/remote/objects/#{remote.id}/follow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='thread_page_thread_controls']//button")).to have("Unfollow")
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
        post "/remote/objects/#{remote.id}/unfollow"
        expect(response.status_code).to eq(302)
      end

      context "within a turbo-frame" do
        it "succeeds" do
          post "/remote/objects/#{remote.id}/unfollow", TURBO_FRAME
          expect(response.status_code).to eq(200)
        end

        it "renders a follow button" do
          post "/remote/objects/#{remote.id}/unfollow", TURBO_FRAME
          expect(body.xpath_nodes("//*[@id='thread_page_thread_controls']//button")).to have("Follow")
        end
      end

      context "given a follow and fetch" do
        let_create(:object, named: :reply, in_reply_to: remote)
        let_create!(:follow_thread_relationship, actor: actor, thread: reply.thread)
        let_create!(:fetch_thread_task, source: actor, thread: reply.thread)

        it "succeeds" do
          post "/remote/objects/#{remote.id}/unfollow"
          expect(response.status_code).to eq(302)
        end

        it "unfollows the thread" do
          post "/remote/objects/#{remote.id}/unfollow"
          expect(Relationship::Content::Follow::Thread.all.map(&.to_iri)).to be_empty
        end

        it "stops fetching the thread" do
          post "/remote/objects/#{remote.id}/unfollow"
          expect(Task::Fetch::Thread.where(complete: true).map(&.subject_iri)).to eq([remote.iri])
        end

        context "within a turbo-frame" do
          it "succeeds" do
            post "/remote/objects/#{remote.id}/unfollow", TURBO_FRAME
            expect(response.status_code).to eq(200)
          end

          it "renders a follow button" do
            post "/remote/objects/#{remote.id}/unfollow", TURBO_FRAME
            expect(body.xpath_nodes("//*[@id='thread_page_thread_controls']//button")).to have("Follow")
          end
        end

        context "given a reply" do
          let_create!(:object, named: :reply, in_reply_to: remote)

          it "succeeds" do
            post "/remote/objects/#{reply.id}/unfollow"
            expect(response.status_code).to eq(302)
          end

          it "unfollows the root object of the thread" do
            post "/remote/objects/#{reply.id}/unfollow"
            expect(Relationship::Content::Follow::Thread.all.map(&.to_iri)).to be_empty
          end

          it "stops fetching the root object of the thread" do
            post "/remote/objects/#{reply.id}/unfollow"
            expect(Task::Fetch::Thread.where(complete: true).map(&.subject_iri)).to eq([remote.iri])
          end

          context "within a turbo-frame" do
            it "succeeds" do
              post "/remote/objects/#{reply.id}/unfollow", TURBO_FRAME
              expect(response.status_code).to eq(200)
            end

            it "renders a follow button" do
              post "/remote/objects/#{reply.id}/unfollow", TURBO_FRAME
              expect(body.xpath_nodes("//*[@id='thread_page_thread_controls']//button")).to have("Follow")
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
end
