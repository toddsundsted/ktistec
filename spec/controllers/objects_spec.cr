require "../../src/controllers/objects"

require "../spec_helper/controller"

Spectator.describe ObjectsController do
  setup_spec

  let(author) do
    ActivityPub::Actor.new(
      iri: "https://nowhere/#{random_string}"
    ).save
  end
  let!(visible) do
    ActivityPub::Object.new(
      iri: "https://test.test/objects/#{random_string}",
      attributed_to: author,
      visible: true
    ).save
  end
  let!(notvisible) do
    ActivityPub::Object.new(
      iri: "https://test.test/objects/#{random_string}",
      attributed_to: author,
      visible: false
    ).save
  end
  let!(remote) do
    ActivityPub::Object.new(
      iri: "https://remote/#{random_string}",
      attributed_to: author
    ).save
  end

  describe "GET /objects/:id" do
    it "succeeds" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/objects/#{visible.iri.split("/").last}", headers
      expect(response.status_code).to eq(200)
    end

    it "succeeds" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/objects/#{visible.iri.split("/").last}", headers
      expect(response.status_code).to eq(200)
    end

    it "renders the object" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/objects/#{visible.iri.split("/").last}", headers
      expect(XML.parse_html(response.body).xpath_nodes("//article/@id").first.text).to eq("object-#{visible.id}")
    end

    it "renders the object" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/objects/#{visible.iri.split("/").last}", headers
      expect(JSON.parse(response.body)["id"]).to eq(visible.iri)
    end

    it "returns 404 if object is not visible" do
      get "/objects/#{notvisible.iri.split("/").last}"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is remote" do
      get "/objects/#{remote.iri.split("/").last}"
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object does not exist" do
      get "/objects/0"
      expect(response.status_code).to eq(404)
    end

    context "when it's in the user's inbox" do
      sign_in

      before_each do
        [visible, notvisible, remote].each do |object|
          Relationship::Content::Inbox.new(
            from_iri: Global.account.not_nil!.iri,
            to_iri: ActivityPub::Activity.new(
              iri: "https://test.test/activities/#{random_string}",
              actor_iri: Global.account.not_nil!.iri,
              object_iri: object.iri
            ).save.iri
          ).save
        end
      end

      it "renders the object" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/objects/#{notvisible.iri.split("/").last}", headers
        expect(response.status_code).to eq(200)
      end

      it "returns 404 if object is remote" do
        get "/objects/#{remote.iri.split("/").last}"
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
      sign_in

      it "succeeds" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}", headers
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{visible.id}", headers
        expect(response.status_code).to eq(200)
      end

      it "renders the object" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}", headers
        expect(XML.parse_html(response.body).xpath_nodes("//article/@id").first.text).to eq("object-#{visible.id}")
      end

      it "renders the object" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{visible.id}", headers
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

      it "returns 404 if object does not exist" do
        get "/remote/objects/0"
        expect(response.status_code).to eq(404)
      end

      context "and it's in the user's inbox" do
        before_each do
          [visible, notvisible, remote].each do |object|
            Relationship::Content::Inbox.new(
              from_iri: Global.account.not_nil!.iri,
              to_iri: ActivityPub::Activity.new(
                iri: "https://test.test/activities/#{random_string}",
                actor_iri: Global.account.not_nil!.iri,
                object_iri: object.iri
              ).save.iri
            ).save
          end
        end

        it "renders the object" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/remote/objects/#{notvisible.id}", headers
          expect(response.status_code).to eq(200)
        end

        it "renders the object" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/remote/objects/#{remote.id}", headers
          expect(response.status_code).to eq(200)
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
      sign_in

      it "returns success" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{visible.id}/thread", headers
        expect(response.status_code).to eq(200)
      end

      it "renders the collection" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{visible.id}/thread", headers
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

      it "returns 404 if object does not exist" do
        get "/remote/objects/0/thread"
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "GET /remote/objects/:id/replies" do
    it "returns 401" do
      get "/remote/objects/0/replies"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "returns success" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}/replies", headers
        expect(response.status_code).to eq(200)
      end

      it "renders the object" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}/replies", headers
        expect(XML.parse_html(response.body).xpath_nodes("//article/@id").first.text).to eq("object-#{visible.id}")
      end

      it "renders the form" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}/replies", headers
        expect(XML.parse_html(response.body).xpath_nodes("//trix-editor")).not_to be_empty
      end

      let(other) do
        ActivityPub::Actor.new(
          iri: "https://nowhere/#{random_string}"
        ).save
      end
      let(parent) do
        ActivityPub::Object.new(
          iri: "https://test.test/objects/#{random_string}",
          attributed_to: other,
          visible: true
        ).save
      end

      before_each do
        visible.assign(in_reply_to: parent).save
      end

      it "addresses (to) the author of the object" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}/replies", headers
        expect(XML.parse_html(response.body).xpath_nodes("//form/input[@name='to']/@value").first.text).to eq(author.iri)
      end

      it "addresses (cc) the other authors in the thread" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/remote/objects/#{visible.id}/replies", headers
        expect(XML.parse_html(response.body).xpath_nodes("//form/input[@name='cc']/@value").first.text).to eq(other.iri)
      end

      it "returns 404 if object is not visible" do
        get "/remote/objects/#{notvisible.id}/replies"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is remote" do
        get "/remote/objects/#{remote.id}/replies"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        get "/remote/objects/0/replies"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
