require "../../src/controllers/lookups"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe LookupsController do
  setup_spec

  let(actor) { register.actor }

  describe "GET /lookup/actor" do
    it "returns 401 if not authorized" do
      get "/lookup/actor"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 400" do
        get "/lookup/actor"
        expect(response.status_code).to eq(400)
      end

      it "returns 404" do
        get "/lookup/actor?iri=unknown"
        expect(response.status_code).to eq(404)
      end

      it "redirects to the actor" do
        get "/lookup/actor?iri=#{URI.encode_path(actor.iri)}"
        expect(response.status_code).to eq(302)
        expect(response.headers["Location"]).to eq("/remote/actors/#{actor.id}")
      end
    end
  end

  describe "GET /lookup/object" do
    it "returns 401 if not authorized" do
      get "/lookup/object"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 400" do
        get "/lookup/object"
        expect(response.status_code).to eq(400)
      end

      it "returns 404" do
        get "/lookup/object?iri=unknown"
        expect(response.status_code).to eq(404)
      end

      context "given a cached object" do
        let_create(object)

        it "redirects to the object" do
          get "/lookup/object?iri=#{URI.encode_path(object.iri)}"
          expect(response.status_code).to eq(302)
          expect(response.headers["Location"]).to eq("/remote/objects/#{object.id}")
        end
      end
    end
  end

  describe "GET /lookup/activity" do
    it "returns 401 if not authorized" do
      get "/lookup/activity"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 400" do
        get "/lookup/activity"
        expect(response.status_code).to eq(400)
      end

      it "returns 404" do
        get "/lookup/activity?iri=unknown"
        expect(response.status_code).to eq(404)
      end

      context "given a cached activity" do
        let_create(activity)

        it "redirects to the activity" do
          get "/lookup/activity?iri=#{URI.encode_path(activity.iri)}"
          expect(response.status_code).to eq(302)
          expect(response.headers["Location"]).to eq("/remote/activities/#{activity.id}")
        end
      end
    end
  end
end
