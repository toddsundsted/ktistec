require "../../../src/services/feed/judging"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"

private class FailingBackend < TestBackend
  class_property error : Exception = Feed::Backend::TransientError.new("judge unavailable")

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
    objects.map do |object|
      raise FailingBackend.error if object.content.try(&.includes?("boom"))
      Judgment.new(included: true)
    end
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

# Deletes the feeds it judges for, as if their owner deleted them
# while it was answering.
#
private class FeedDeletingBackend < TestBackend
  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
    Feed.where(version_id: feed.version_id).each(&.destroy)
    objects.map { Judgment.new(included: true) }
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

Spectator.describe Feed::Judging do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

  def retry_for(object, feed = self.feed)
    Feed::Question.find?(version_id: feed.version_id, object_iri: object.iri, batched: false)
  end

  describe ".answer" do
    let_create!(:object, named: hit, content: "<p>something alpha something</p>")

    let_create(:feed_question, named: question, feed: feed, object: hit, batched: true)

    def verdict_for(object, feed = self.feed)
      Feed::Verdict.find?(version_id: feed.version_id, object_iri: object.iri)
    end

    it "includes the matching object" do
      Feed::Judging.answer(question)
      expect(verdict_for(hit).try(&.included)).to be_true
    end

    it "records the judge's reason" do
      Feed::Judging.answer(question)
      expect(verdict_for(hit).try(&.reason)).to match(/alpha/)
    end

    context "given a post that does not match" do
      before_each { hit.assign(content: "<p>something gamma something</p>").save }

      it "excludes the post" do
        Feed::Judging.answer(question)
        expect(verdict_for(hit).try(&.included)).to be_false
      end
    end

    context "given a post that is not a candidate" do
      before_each { hit.assign(visible: false).save }

      it "writes no verdict" do
        Feed::Judging.answer(question)
        expect(verdict_for(hit)).to be_nil
      end

      context "but is a candidate for another feed on the same version" do
        let(recipient) { register.actor }
        let_create!(:feed, named: other, owner: recipient, params: feed.params)
        let_create(:create, object: hit)

        before_each { put_in_inbox(recipient, create) }

        pre_condition { expect(other.version_id).to eq(feed.version_id) }

        it "includes the matching object" do
          Feed::Judging.answer(question)
          expect(verdict_for(hit).try(&.included)).to be_true
        end
      end
    end

    context "when the feed is deleted while the judge answers" do
      register_backend("feed-deleting", FeedDeletingBackend.new)

      let_create!(:feed, owner: actor, backend: "feed-deleting")

      it "discards the answer" do
        Feed::Judging.answer(question)
        expect(verdict_for(hit)).to be_nil
      end
    end

    context "given a past failure" do
      let_create!(:feed_verdict, named: nil, feed: feed, object: hit, included: false, failure: Feed::Verdict::TRANSIENT)

      it "replaces the failure" do
        Feed::Judging.answer(question)
        expect(verdict_for(hit).try(&.failed?)).to be_false
      end
    end

    context "when the judge fails" do
      register_backend("failing", FailingBackend.new)

      let_create!(:feed, owner: actor, backend: "failing")
      let_create!(:object, named: hit, content: "<p>boom</p>")

      context "and the failure is transient" do
        before_each { FailingBackend.error = Feed::Backend::TransientError.new("judge unavailable") }

        it "records a transient failure" do
          Feed::Judging.answer(question)
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::TRANSIENT)
        end

        it "records the failure's reason" do
          Feed::Judging.answer(question)
          expect(verdict_for(hit).try(&.reason)).to match(/judge unavailable/)
        end

        it "asks again later" do
          Feed::Judging.answer(question)
          expect(retry_for(hit).try(&.due_at)).to be_close(Feed::Judging::RETRY_DELAY.from_now, delta: 1.second)
        end

        it "asks again as backfill" do
          Feed::Judging.answer(question)
          expect(retry_for(hit).try(&.live)).to be_false
        end

        context "and the question is live" do
          before_each { question.assign(live: true).save }

          it "asks again as live" do
            Feed::Judging.answer(question)
            expect(retry_for(hit).try(&.live)).to be_true
          end
        end
      end

      context "and the failure is permanent" do
        before_each { FailingBackend.error = Feed::Backend::PermanentError.new("judge misconfigured") }

        it "records a permanent failure" do
          Feed::Judging.answer(question)
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::PERMANENT)
        end

        it "records the failure's reason" do
          Feed::Judging.answer(question)
          expect(verdict_for(hit).try(&.reason)).to match(/judge misconfigured/)
        end

        it "does not ask again" do
          Feed::Judging.answer(question)
          expect(retry_for(hit)).to be_nil
        end
      end

      context "and the failure is unclassified" do
        before_each { FailingBackend.error = Exception.new("judge crashed") }

        it "records a transient failure" do
          Feed::Judging.answer(question)
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::TRANSIENT)
        end
      end
    end
  end
end
