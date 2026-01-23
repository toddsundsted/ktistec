require "../../../../src/models/activity_pub/object/question"
require "../../../../src/models/activity_pub/object/note"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Object::Question do
  setup_spec

  describe "#supported_editors" do
    RichText = ActivityPub::Object::EditorType::RichText
    Markdown = ActivityPub::Object::EditorType::Markdown
    Optional = ActivityPub::Object::EditorType::Optional
    Poll     = ActivityPub::Object::EditorType::Poll

    let_build(:question)

    context "with no source" do
      it "returns RichText, Markdown, Optional, and Poll" do
        expect(question.supported_editors).to contain_exactly(RichText, Markdown, Optional, Poll).in_any_order
      end
    end

    context "with source" do
      context "and text/html media type" do
        it "returns RichText, Optional, and Poll" do
          question.source = ActivityPub::Object::Source.new("content", "text/html")
          expect(question.supported_editors).to contain_exactly(RichText, Optional, Poll).in_any_order
        end
      end

      context "and text/markdown media type" do
        it "returns Markdown, Optional, and Poll" do
          question.source = ActivityPub::Object::Source.new("content", "text/markdown")
          expect(question.supported_editors).to contain_exactly(Markdown, Optional, Poll).in_any_order
        end
      end

      context "and unsupported media type" do
        it "returns Optional and Poll" do
          question.source = ActivityPub::Object::Source.new("content", "text/plain")
          expect(question.supported_editors).to contain_exactly(Optional, Poll).in_any_order
        end
      end
    end
  end

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

  describe "#from_json_ld" do
    let(question) { poll.question }

    let(json_string) do
      <<-JSON
      {
        "@context": [
          "https://www.w3.org/ns/activitystreams",
          {"votersCount": "http://joinmastodon.org/ns#votersCount"}
        ],
        "id": #{question.iri.to_json},
        "type": "Question",
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
        "votersCount": 50
      }
      JSON
    end

    it "replaces poll instance" do
      expect { question.from_json_ld(json_string) }.to change { question.poll }.from(poll)
    end

    it "updates voters count" do
      expect { question.from_json_ld(json_string) }.to change { question.poll.voters_count }.to(50)
    end

    it "updates content" do
      expect { question.from_json_ld(json_string) }.to change { question.content }.to("Do you like polls?")
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

  # Vote Tracking

  let_create(:actor, local: true)

  let_create(:poll, options: [
    Poll::Option.new("Yes", 0),
    Poll::Option.new("No", 0),
  ])

  let(question) { poll.question }

  macro vote(index, actor = actor)
    let_create!(
      :note,
      named: vote{{index}},
      name: poll.options[{{index}}].name,
      in_reply_to: question,
      attributed_to: {{actor}},
      content: nil,
      special: "vote",
    )
  end

  describe "#votes" do
    it "returns empty array when no votes" do
      expect(question.votes).to be_empty
    end

    context "with single vote" do
      vote(0)

      it "returns all votes" do
        votes = question.votes
        expect(votes.size).to eq(1)
        expect(votes.map(&.name)).to contain_exactly("Yes")
      end
    end

    context "with multiple votes from same voter" do
      vote(0)
      vote(1)

      it "returns all votes" do
        votes = question.votes
        expect(votes.size).to eq(2)
        expect(votes.map(&.name)).to contain_exactly("Yes", "No")
      end
    end

    context "with multiple voters" do
      vote(0, voter1)
      vote(1, voter2)

      let_create(:actor, named: voter1, local: true)
      let_create(:actor, named: voter2, local: true)

      it "returns all votes" do
        votes = question.votes
        expect(votes.size).to eq(2)
        expect(votes.map(&.name)).to contain_exactly("Yes", "No")
      end
    end

    context "with a reply" do
      let_create!(
        :note,
        named: reply,
        name: nil,
        content: "This is a regular reply",
        in_reply_to: question,
        attributed_to: actor,
      )

      it "ignores replies" do
        expect(question.votes).to be_empty
      end
    end
  end

  describe "#votes_by" do
    it "returns empty array" do
      expect(question.votes_by(actor)).to be_empty
    end

    context "with single vote" do
      vote(0)

      it "returns votes for actor" do
        votes = question.votes_by(actor)
        expect(votes.size).to eq(1)
        expect(votes.map(&.name)).to contain_exactly("Yes")
      end
    end

    context "with multiple votes" do
      vote(0)
      vote(1)

      it "returns votes for actor" do
        votes = question.votes_by(actor)
        expect(votes.size).to eq(2)
        expect(votes.map(&.name)).to contain_exactly("Yes", "No")
      end
    end

    context "with other actor's vote" do
      let_create(:actor, named: other, local: true)

      let_create!(
        :note,
        named: other_vote,
        name: "Yes",
        in_reply_to: question,
        attributed_to: other,
        content: nil,
        special: "vote",
      )

      it "ignores the other vote" do
        expect(question.votes_by(actor)).to be_empty
      end
    end
  end

  describe "#voted_by?" do
    it "returns false" do
      expect(question.voted_by?(actor)).to be_false
    end

    context "when actor has voted" do
      vote(0)

      it "returns true" do
        expect(question.voted_by?(actor)).to be_true
      end
    end

    context "with reply" do
      let_create!(
        :note,
        named: reply,
        name: nil,
        content: "This is a regular reply",
        in_reply_to: question,
        attributed_to: actor,
      )

      it "ignores the reply" do
        expect(question.voted_by?(actor)).to be_false
      end
    end
  end

  describe "#options_by" do
    context "with single vote" do
      vote(0)

      it "returns options voted for" do
        options = question.options_by(actor)
        expect(options).to contain_exactly("Yes")
      end
    end

    context "with multiple votes" do
      vote(0)
      vote(1)

      it "returns options voted for" do
        options = question.options_by(actor)
        expect(options).to contain_exactly("Yes", "No")
      end
    end
  end

  describe "#voters" do
    context "with single voter" do
      vote(0)

      it "returns all voters" do
        voters = question.voters
        expect(voters.size).to eq(1)
        expect(voters).to contain_exactly(actor)
      end
    end

    context "with multiple voters" do
      vote(0, voter1)
      vote(1, voter2)

      let_create(:actor, named: voter1, local: true)
      let_create(:actor, named: voter2, local: true)

      it "returns all voters" do
        voters = question.voters
        expect(voters.size).to eq(2)
        expect(voters).to contain_exactly(voter1, voter2)
      end
    end

    context "with same voter voting multiple times" do
      vote(0)
      vote(1)

      it "returns each voter only once" do
        voters = question.voters
        expect(voters.size).to eq(1)
        expect(voters).to contain_exactly(actor)
      end
    end

    context "with a reply" do
      let_create!(
        :note,
        named: reply,
        name: nil,
        content: "This is a regular reply",
        in_reply_to: question,
        attributed_to: actor,
      )

      it "ignores replies" do
        expect(question.voters).to be_empty
      end
    end
  end
end
