require "../../src/controllers/activities"

require "../spec_helper/factory"
require "../spec_helper/controller"

# redefine as public for testing
class ActivitiesController
  def self.get_activity(env, iri_or_id)
    previous_def(env, iri_or_id)
  end
end

Spectator.describe ActivitiesController do
  setup_spec

  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json"}

  let_create!(:activity, named: :visible, visible: true, local: true)
  let_create!(:activity, named: :notvisible, visible: false, local: true)
  let_create!(:activity, named: :remote)

  describe ".get_activity" do
    let(env) { env_factory("GET", "/") }

    it "returns visible activities" do
      result = ActivitiesController.get_activity(env, visible.iri)
      expect(result).to eq(visible)
    end

    it "returns nil for non-visible activities" do
      result = ActivitiesController.get_activity(env, notvisible.iri)
      expect(result).to be_nil
    end

    context "when authenticated" do
      sign_in

      it "returns visible activities" do
        result = ActivitiesController.get_activity(env, visible.iri)
        expect(result).to eq(visible)
      end

      it "returns nil for non-visible activities" do
        result = ActivitiesController.get_activity(env, notvisible.iri)
        expect(result).to be_nil
      end

      context "and account actor is the actor" do
        before_each do
          notvisible.assign(actor_iri: Global.account.not_nil!.iri).save
        end

        it "returns non-visible activities owned by the actor" do
          result = ActivitiesController.get_activity(env, notvisible.iri)
          expect(result).to eq(notvisible)
        end
      end

      context "and activity is in account actor's inbox" do
        before_each do
          put_in_inbox(owner: Global.account.not_nil!.actor, activity: notvisible)
        end

        it "returns non-visible activities in the actor's inbox" do
          result = ActivitiesController.get_activity(env, notvisible.iri)
          expect(result).to eq(notvisible)
        end
      end
    end
  end

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
