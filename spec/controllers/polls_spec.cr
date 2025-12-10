require "../../src/controllers/polls"
require "../../src/models/task/deliver"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe PollsController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}

  describe "POST /polls/:id/vote" do
    let_create!(:question)
    let_create!(:poll, question: question, options: [
      Poll::Option.new("Yes", 0),
      Poll::Option.new("No", 0)
    ])

    let(actor) { register.actor }

    it "returns 401 if not authorized" do
      post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes"
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "rejects votes on expired polls" do
        poll.assign(closed_at: 1.day.ago).save
        post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes"
        expect(response.status_code).to eq(422)
      end

      it "rejects votes on expired polls" do
        poll.assign(closed_at: 1.day.ago).save
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
        expect(response.status_code).to eq(422)
      end

      it "requires at least one option" do
        post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]="
        expect(response.status_code).to eq(422)
      end

      it "requires at least one option" do
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": []})
        expect(response.status_code).to eq(422)
      end

      it "validates options exist in poll" do
        post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Invalid"
        expect(response.status_code).to eq(422)
      end

      it "validates options exist in poll" do
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Invalid"]})
        expect(response.status_code).to eq(422)
      end

      # For each vote

      it "assigns published" do
        post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes"
        expect(question.votes_by(actor).all?(&.published.is_a?(Time))).to be_true
      end

      it "assigns to" do
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
        expect(question.votes_by(actor).flat_map(&.to)).to contain_exactly(question.attributed_to.iri)
      end

      it "does not assign cc" do
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
        expect(question.votes_by(actor).flat_map(&.cc)).to be_empty
      end

      it "wraps votes in create activities" do
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
        expect(question.votes_by(actor).all?(&.activities.any?(&.is_a?(ActivityPub::Activity::Create)))).to be_true
      end

      it "schedules deliveries of activities" do
        post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})

        question.votes_by(actor).each do |vote|
          create_activity = ActivityPub::Activity::Create.find(actor: actor, object: vote)
          expect(Task::Deliver.find?(sender: actor, activity: create_activity)).not_to be_nil
        end
      end

      context "with single-choice poll" do
        it "prevents multiple selections" do
          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes&options[]=No"
          expect(response.status_code).to eq(422)
        end

        it "prevents multiple selections" do
          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes", "No"]})
          expect(response.status_code).to eq(422)
        end

        it "prevents more than one votes" do
          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes"
          expect(response.status_code).to eq(302)

          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=No"
          expect(response.status_code).to eq(422)
        end

        it "prevents more than one votes" do
          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
          expect(response.status_code).to eq(302)

          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["No"]})
          expect(response.status_code).to eq(422)
        end

        it "creates vote and returns success" do
          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes"
          expect(response.status_code).to eq(302)

          votes = question.votes_by(actor)
          expect(votes.size).to eq(1)
          expect(votes.first.name).to eq("Yes")
        end

        it "creates vote and returns success" do
          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
          expect(response.status_code).to eq(302)

          votes = question.votes_by(actor)
          expect(votes.size).to eq(1)
          expect(votes.first.name).to eq("Yes")
        end
      end

      context "with multiple-choice poll" do
        before_each { poll.assign(multiple_choice: true).save }

        it "allows multiple selections" do
          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes&options[]=No"
          expect(response.status_code).to eq(302)
        end

        it "allows multiple selections" do
          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes", "No"]})
          expect(response.status_code).to eq(302)
        end

        it "prevents more than one votes" do
          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes"
          expect(response.status_code).to eq(302)

          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=No"
          expect(response.status_code).to eq(422)
        end

        it "prevents more than one votes" do
          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes"]})
          expect(response.status_code).to eq(302)

          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["No"]})
          expect(response.status_code).to eq(422)
        end

        it "creates votes and returns success" do
          post "/polls/#{poll.id}/vote", HTML_HEADERS, "options[]=Yes&options[]=No"
          expect(response.status_code).to eq(302)

          votes = question.votes_by(actor)
          expect(votes.size).to eq(2)
          expect(votes.map(&.name)).to contain_exactly("Yes", "No")
        end

        it "creates votes and returns success" do
          post "/polls/#{poll.id}/vote", JSON_HEADERS, %({"options": ["Yes", "No"]})
          expect(response.status_code).to eq(302)

          votes = question.votes_by(actor)
          expect(votes.size).to eq(2)
          expect(votes.map(&.name)).to contain_exactly("Yes", "No")
        end
      end
    end
  end
end
