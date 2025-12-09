require "../../../../src/models/activity_pub/object/question"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Object::Question do
  setup_spec

  describe ".map" do
    let(attrs) { ActivityPub::Object::Question.map(json_string) }
    let(poll) { attrs["poll"].as(Poll) }

    context "with votersCount" do
      let(json_string) do
        <<-JSON
        {
          "@context": [
            "https://www.w3.org/ns/activitystreams",
            {
              "votersCount": "http://joinmastodon.org/ns#votersCount"
            }
          ],
          "type": "Question",
          "id": "https://remote/questions/1",
          "votersCount": 42
        }
        JSON
      end

      it "extracts voters count" do
        expect(poll.voters_count).to eq(42)
      end
    end

    context "with oneOf" do
      let(json_string) do
        <<-JSON
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "type": "Question",
          "id": "https://remote/questions/1",
          "oneOf": [
            {
              "type": "Note",
              "name": "Yes",
              "replies": {"type": "Collection", "totalItems": 42}
            },
            {
              "type": "Note",
              "name": "No",
              "replies": {"type": "Collection", "totalItems": 8}
            }
          ]
        }
        JSON
      end

      it "creates poll with options" do
        expect(poll.options.size).to eq(2)
      end

      it "extracts names" do
        expect(poll.options[0].name).to eq("Yes")
        expect(poll.options[1].name).to eq("No")
      end

      it "extracts vote counts" do
        expect(poll.options[0].votes_count).to eq(42)
        expect(poll.options[1].votes_count).to eq(8)
      end

      it "sets multiple_choice to false" do
        expect(poll.multiple_choice).to be_false
      end
    end

    context "with anyOf" do
      let(json_string) do
        <<-JSON
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "type": "Question",
          "id": "https://remote/questions/2",
          "anyOf": [
            {
              "type": "Note",
              "name": "Option A",
              "replies": {"type": "Collection", "totalItems": 10}
            },
            {
              "type": "Note",
              "name": "Option B",
              "replies": {"type": "Collection", "totalItems": 15}
            },
            {
              "type": "Note",
              "name": "Option C",
              "replies": {"type": "Collection", "totalItems": 5}
            }
          ]
        }
        JSON
      end

      it "creates poll with options" do
        expect(poll.options.size).to eq(3)
      end

      it "extracts names" do
        expect(poll.options[0].name).to eq("Option A")
        expect(poll.options[1].name).to eq("Option B")
        expect(poll.options[2].name).to eq("Option C")
      end

      it "extracts vote counts" do
        expect(poll.options[0].votes_count).to eq(10)
        expect(poll.options[1].votes_count).to eq(15)
        expect(poll.options[2].votes_count).to eq(5)
      end

      it "sets multiple_choice to true" do
        expect(poll.multiple_choice).to be_true
      end
    end

    context "with endTime" do
      let(json_string) do
        <<-JSON
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "type": "Question",
          "id": "https://remote/questions/3",
          "endTime": "2025-12-31T23:59:59Z"
        }
        JSON
      end

      it "extracts endTime as closed_at" do
        expect(poll.closed_at).to_not be_nil
        expect(poll.closed_at.to_s).to contain("2025-12-31")
        expect(poll.closed_at.to_s).to contain("23:59:59")
      end
    end

    context "with closed timestamp" do
      let(json_string) do
        <<-JSON
        {
          "@context": [
            "https://www.w3.org/ns/activitystreams",
            {"closed": "http://joinmastodon.org/ns#closed"}
          ],
          "type": "Question",
          "id": "https://remote/questions/4",
          "closed": "2025-01-15T10:00:00Z"
        }
        JSON
      end

      it "extracts closed as closed_at" do
        expect(poll.closed_at).to_not be_nil
        expect(poll.closed_at.to_s).to contain("2025-01-15")
        expect(poll.closed_at.to_s).to contain("10:00:00")
      end
    end

    context "without poll-specific fields" do
      let(json_string) do
        <<-JSON
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "type": "Question",
          "id": "https://remote/questions/6",
          "content": "Just a question"
        }
        JSON
      end

      it "does not create poll when oneOf/anyOf missing" do
        expect(poll.options).to be_empty
        expect(poll.voters_count).to be_nil
      end
    end
  end

  describe ".from_json_ld" do
    let(json_string) do
      <<-JSON
      {
        "@context": [
          "https://www.w3.org/ns/activitystreams",
          {
            "votersCount": "http://joinmastodon.org/ns#votersCount"
          }
        ],
        "type": "Question",
        "id": "https://remote/questions/1",
        "content": "Do you like polls?",
        "oneOf": [
          {
            "type": "Note",
            "name": "Yes",
            "replies": {"type": "Collection", "totalItems": 42}
          },
          {
            "type": "Note",
            "name": "No",
            "replies": {"type": "Collection", "totalItems": 8}
          }
        ],
        "endTime": "2025-12-31T23:59:59Z",
        "votersCount": 50
      }
      JSON
    end

    let(question) { ActivityPub::Object.from_json_ld(json_string) }

    it "creates ActivityPub::Object::Question" do
      expect(question).to be_a(ActivityPub::Object::Question)
    end

    it "extracts content" do
      expect(question.content).to eq("Do you like polls?")
    end

    it "has a poll" do
      expect(question.as(ActivityPub::Object::Question).poll?).to_not be_nil
    end

    it "extracts voters count" do
      expect(question.as(ActivityPub::Object::Question).poll.voters_count).to eq(50)
    end
  end

  describe "#save" do
    let_create(:question)

    it "deletes old poll when saving new poll" do
      old_poll = Poll.new(
        question: question,
        options: [Poll::Option.new("Old 1"), Poll::Option.new("Old 2")]
      ).save
      expect(old_poll.id).not_to be_nil

      expect(Poll.count(question: question)).to eq(1)

      new_poll = Poll.new(
        question: question,
        options: [Poll::Option.new("New 1"), Poll::Option.new("New 2")]
      ).save
      expect(new_poll.id).not_to be_nil

      expect(new_poll.id).not_to eq(old_poll.id)

      expect(Poll.count(question: question, include_deleted: true, include_undone: true)).to eq(1)
      expect(Poll.find?(old_poll.id)).to be_nil
      expect(Poll.find(new_poll.id)).not_to be_nil
    end
  end
end
