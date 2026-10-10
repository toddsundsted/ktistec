require "../../../../src/models/task/feed/answer_questions"
require "../../../../src/services/feed/backend/criteria"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"
require "../../../spec_helper/feed/backend"

class AnswerQuestionsSpy < Task::Feed::AnswerQuestions
  getter reconcile_calls = [] of String

  protected def reconcile_answer(question : ::Feed::Question) : Nil
    reconcile_calls << question.object_iri.not_nil!
  end
end

Spectator.describe Task::Feed::AnswerQuestions do
  setup_spec

  private class DestroyingBackend < TestBackend
    def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
      Feed::Version.find?(feed.version_id).try(&.destroy)
      objects.map { Judgment.new(included: true).as(Judgment | Failure) }
    end

    def validate_params(params : Hash(String, JSON::Any)) : Array(String)
      [] of String
    end
  end

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

  subject { AnswerQuestionsSpy.new }

  describe "#perform" do
    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).to be_close(Task::Feed::AnswerQuestions::INTERVAL.from_now, delta: 1.second)
    end

    context "given questions" do
      let_create!(:object, named: hit, content: "<p>alpha</p>")
      let_create!(:object, named: miss, content: "<p>gamma</p>")
      let_create!(:feed_question, named: hit_question, feed: feed, object: hit)
      let_create!(:feed_question, named: miss_question, feed: feed, object: miss)

      it "answers them" do
        subject.perform
        expect(subject.reconcile_calls).to contain_exactly(hit.iri, miss.iri).in_any_order
      end

      it "removes them" do
        subject.perform
        expect(Feed::Question.count).to eq(0)
      end
    end
  end
end
