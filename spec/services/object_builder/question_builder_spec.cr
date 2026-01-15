require "../../../src/services/object_builder/question_builder"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe ObjectBuilder::QuestionBuilder do
  setup_spec

  subject { described_class.new }

  let_create!(:actor, local: true)

  describe "#build" do
    let(params) do
      {
        "content"      => "What is your favorite color?",
        "poll-options" => ["Red", "Blue", "Green"],
        "visibility"   => "public",
      }
    end

    it "creates a Question" do
      result = subject.build(params, actor)
      expect(result.valid?).to be_true
      expect(result.object).to be_a(ActivityPub::Object::Question)
    end

    it "assigns unique IRI" do
      result = subject.build(params, actor)
      expect(result.object.iri).to match(/^https:\/\/test\.test\/objects\/[a-zA-Z0-9_-]+/)
    end

    it "creates a Poll" do
      result = subject.build(params, actor)
      expect(result.valid?).to be_true
      expect(result.object.as(ActivityPub::Object::Question).poll).to be_a(Poll)
    end

    macro poll
      result.object.as(ActivityPub::Object::Question).poll.not_nil!
    end

    it "extracts poll options" do
      result = subject.build(params, actor)
      expect(poll.options.map(&.name)).to eq(["Red", "Blue", "Green"])
    end

    it "strips whitespace from options" do
      params["poll-options"] = [" Red ", " Blue ", " Green "]
      result = subject.build(params, actor)
      expect(poll.options.map(&.name)).to eq(["Red", "Blue", "Green"])
    end

    it "extracts poll duration" do
      params["poll-duration"] = "3600"
      result = subject.build(params, actor)
      expect(poll.closed_at).to eq(Time.unix(3600))
    end

    it "extracts poll multiple choice" do
      params["poll-multiple-choice"] = "true"
      result = subject.build(params, actor)
      expect(poll.multiple_choice).to be_true
    end

    context "given a draft question" do
      let_build(
        :question,
        attributed_to: actor,
        local: true,
      )
      let_build!(
        :poll,
        question: question,
        options: [Poll::Option.new("Red", 0), Poll::Option.new("Blue", 0)],
        closed_at: Time.unix(3600),
      )

      it "allows changing poll options" do
        params["poll-options"] = ["Yellow", "Purple", "Orange"]
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_true
        expect(poll.options.map(&.name)).to eq(["Yellow", "Purple", "Orange"])
      end

      it "allows changing poll duration" do
        params["poll-duration"] = "7200"
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_true
        expect(poll.closed_at).to eq(Time.unix(7200))
      end

      it "allows changing multiple_choice" do
        params["poll-multiple-choice"] = "true"
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_true
        expect(poll.multiple_choice).to be_true
      end
    end

    context "given a published question" do
      let_create(
        :question,
        attributed_to: actor,
        local: true,
        published: 3.hours.ago,
      )
      let_create!(
        :poll,
        question: question,
        options: [Poll::Option.new("Red", 0), Poll::Option.new("Blue", 0)],
        closed_at: 2.hours.ago,
      )

      it "disallows changing poll options" do
        params["poll-options"] = ["Yellow", "Purple", "Orange"]
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_false
        expect(result.errors["poll_options"]).to contain("cannot be changed after publishing")
      end

      it "disallows changing poll duration" do
        params["poll-duration"] = "7200"
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_false
        expect(result.errors["poll_duration"]).to contain("cannot be changed after publishing")
      end

      it "disallows changing multiple_choice" do
        params["poll-multiple-choice"] = "true"
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_false
        expect(result.errors["poll_multiple_choice"]).to contain("cannot be changed after publishing")
      end

      it "allows editing question content" do
        params = {"content" => "Updated question text"}
        result = subject.build(params, actor, question)
        expect(result.valid?).to be_true
        expect(poll.options.map(&.name)).to eq(["Red", "Blue"])
        expect(poll.closed_at).to be_close(2.hours.ago, 1.second)
      end
    end

    context "when object has validation errors" do
      let(params) do
        super.tap { |hash| hash["canonical-path"] = "invalid-no-slash" }
      end

      it "adds model errors to result" do
        result = subject.build(params, actor)
        expect(result.valid?).to be_false
        expect(result.errors).to have_key("canonical_path.from_iri")
        expect(result.errors["canonical_path.from_iri"]).to have("must be absolute")
      end
    end

    context "when poll has validation errors" do
      let(params) do
        super.tap { |hash| hash["poll-options"] = ["One option"] }
      end

      it "adds poll errors to result" do
        result = subject.build(params, actor)
        expect(result.valid?).to be_false
        expect(result.errors).to have_key("poll.options")
        expect(result.errors["poll.options"]).to contain("must contain at least 2 options")
      end
    end
  end
end
