require "../spec_helper"

Spectator.describe ObjectsController do
  setup_spec

  let!(visible) do
    ActivityPub::Object.new(iri: "https://test.test/objects/#{random_string}", visible: true).save
  end
  let!(notvisible) do
    ActivityPub::Object.new(iri: "https://test.test/objects/#{random_string}", visible: false).save
  end
  let!(remote) do
    ActivityPub::Object.new(iri: "https://remote/#{random_string}").save
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
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/objects/#{notvisible.iri.split("/").last}", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object is remote" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/objects/#{remote.iri.split("/").last}", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if object does not exist" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/objects/0", headers
      expect(response.status_code).to eq(404)
    end

    context "when the user is a recipient" do
      sign_in

      before_each do
        [visible, notvisible, remote].each do |object|
          object.assign(to: [Global.account.not_nil!.iri]).save
        end
      end

      it "renders the object" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/objects/#{notvisible.iri.split("/").last}", headers
        expect(response.status_code).to eq(200)
      end

      it "returns 404 if object is remote" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/objects/#{remote.iri.split("/").last}", headers
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "GET /remote/objects/:id" do
    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/remote/objects/0", headers
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
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{notvisible.id}", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is remote" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{remote.id}", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/0", headers
        expect(response.status_code).to eq(404)
      end

      context "and it is addressed to the public collection" do
        before_each do
          [visible, notvisible, remote].each do |object|
            object.assign(to: ["https://www.w3.org/ns/activitystreams#Public"]).save
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

      context "and the user is a recipient" do
        before_each do
          [visible, notvisible, remote].each do |object|
            object.assign(cc: [Global.account.not_nil!.iri]).save
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
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/remote/objects/0/thread", headers
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
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{notvisible.id}/thread", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object is remote" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/#{remote.id}/thread", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if object does not exist" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/remote/objects/0/thread", headers
        expect(response.status_code).to eq(404)
      end
    end
  end
end
