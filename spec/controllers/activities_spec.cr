require "../../src/controllers/activities"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe ActivitiesController do
  setup_spec

  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json"}

  let_create!(:activity, named: :visible, visible: true, local: true)
  let_create!(:activity, named: :notvisible, visible: false, local: true)
  let_create!(:activity, named: :remote)

  describe "GET /activities/:id" do
    it "renders the activity" do
      get "/activities/#{visible.iri.split("/").last}", JSON_HEADERS
      expect(response.status_code).to eq(200)
    end

    it "returns 404 if activity is not visible" do
      get "/activities/#{notvisible.iri.split("/").last}", JSON_HEADERS
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if activity is remote" do
      get "/activities/#{remote.iri.split("/").last}", JSON_HEADERS
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if activity does not exist" do
      get "/activities/000", JSON_HEADERS
      expect(response.status_code).to eq(404)
    end

    context "when the user is the owner" do
      sign_in

      before_each do
        [visible, notvisible, remote].each do |activity|
          activity.assign(actor_iri: Global.account.not_nil!.iri).save
        end
      end

      it "renders the activity" do
        get "/activities/#{notvisible.iri.split("/").last}", JSON_HEADERS
        expect(response.status_code).to eq(200)
      end

      it "returns 404 if activity is remote" do
        get "/activities/#{remote.iri.split("/").last}", JSON_HEADERS
        expect(response.status_code).to eq(404)
      end
    end
  end

  describe "GET /remote/activities/:id" do
    it "returns 401 if not authorized" do
      get "/remote/activities/0", JSON_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "renders the activity" do
        get "/remote/activities/#{visible.id}", JSON_HEADERS
        expect(response.status_code).to eq(200)
      end

      it "returns 404 if activity is not visible" do
        get "/remote/activities/#{notvisible.id}", JSON_HEADERS
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if activity is remote" do
        get "/remote/activities/#{remote.id}", JSON_HEADERS
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if activity does not exist" do
        get "/remote/activities/0", JSON_HEADERS
        expect(response.status_code).to eq(404)
      end

      context "and it is addressed to the public collection" do
        before_each do
          [visible, notvisible, remote].each do |activity|
            activity.assign(to: ["https://www.w3.org/ns/activitystreams#Public"]).save
          end
        end

        it "renders the activity" do
          get "/remote/activities/#{notvisible.id}", JSON_HEADERS
          expect(response.status_code).to eq(200)
        end

        it "renders the activity" do
          get "/remote/activities/#{remote.id}", JSON_HEADERS
          expect(response.status_code).to eq(200)
        end
      end

      context "and the user is the owner" do
        before_each do
          [visible, notvisible, remote].each do |activity|
            activity.assign(actor_iri: Global.account.not_nil!.iri).save
          end
        end

        it "renders the activity" do
          get "/remote/activities/#{notvisible.id}", JSON_HEADERS
          expect(response.status_code).to eq(200)
        end

        it "renders the activity" do
          get "/remote/activities/#{remote.id}", JSON_HEADERS
          expect(response.status_code).to eq(200)
        end
      end
    end
  end
end
