require "../../../src/services/feed/judging"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"

private class FailingBackend < TestBackend
  class_property error : Exception = Feed::Backend::TransientError.new("judge unavailable")

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
    objects.map do |object|
      raise FailingBackend.error if object.content.try(&.includes?("boom"))
      Judgment.new(included: true).as(Judgment | Failure)
    end
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

private class ReportingBackend < TestBackend
  class_property kind : Feed::Backend::Failure::Kind = :transient

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
    objects.map do |object|
      if object.content.try(&.includes?("boom"))
        Failure.new(ReportingBackend.kind, "post is unreadable")
      else
        Judgment.new(included: true)
      end
    end
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

private class RecordingBackend < TestBackend
  class_getter calls = [] of Array(String)

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
    RecordingBackend.calls << objects.map(&.iri)
    objects.map { Judgment.new(included: true).as(Judgment | Failure) }
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

# Deletes the feeds it judges for, as if their owner deleted them
# while it was answering.
#
private class FeedDeletingBackend < TestBackend
  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
    Feed.where(version_id: feed.version_id).each(&.destroy)
    objects.map { Judgment.new(included: true).as(Judgment | Failure) }
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
      Feed::Judging.answer([question])
      expect(verdict_for(hit).try(&.included)).to be_true
    end

    it "records the judge's reason" do
      Feed::Judging.answer([question])
      expect(verdict_for(hit).try(&.reason)).to match(/alpha/)
    end

    context "given a post that does not match" do
      before_each { hit.assign(content: "<p>something gamma something</p>").save }

      it "writes no verdict" do
        Feed::Judging.answer([question])
        expect(verdict_for(hit)).to be_nil
      end

      context "and an existing verdict" do
        let_create!(:feed_verdict, named: nil, feed: feed, object: hit, included: true)

        it "deletes the verdict" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit)).to be_nil
        end
      end
    end

    context "given a post that is not a candidate" do
      before_each { hit.assign(visible: false).save }

      it "writes no verdict" do
        Feed::Judging.answer([question])
        expect(verdict_for(hit)).to be_nil
      end
    end

    context "given another question in the batch" do
      register_backend("recording", RecordingBackend.new)

      let_create!(:feed, owner: actor, backend: "recording")
      let_create!(:object, named: other, content: "<p>something else</p>")
      let_create(:feed_question, named: second, feed: feed, object: other, batched: true)

      before_each { RecordingBackend.calls.clear }

      it "asks the judge once" do
        Feed::Judging.answer([question, second])
        expect(RecordingBackend.calls).to eq([[hit.iri, other.iri]])
      end

      it "writes a verdict for both" do
        Feed::Judging.answer([question, second])
        expect([verdict_for(hit), verdict_for(other)].map(&.try(&.included))).to eq([true, true])
      end

      context "whose post is not a candidate" do
        before_each { other.assign(visible: false).save }

        it "does not ask the judge about it" do
          Feed::Judging.answer([question, second])
          expect(RecordingBackend.calls).to eq([[hit.iri]])
        end

        it "does not write a verdict for it" do
          Feed::Judging.answer([question, second])
          expect(verdict_for(other)).to be_nil
        end
      end
    end

    context "when the feed is deleted while the judge answers" do
      register_backend("feed-deleting", FeedDeletingBackend.new)

      let_create!(:feed, owner: actor, backend: "feed-deleting")

      it "discards the answer" do
        Feed::Judging.answer([question])
        expect(verdict_for(hit)).to be_nil
      end
    end

    context "given a past failure" do
      let_create!(:feed_verdict, named: nil, feed: feed, object: hit, included: false, failure: Feed::Verdict::TRANSIENT)

      it "replaces the failure" do
        Feed::Judging.answer([question])
        expect(verdict_for(hit).try(&.failed?)).to be_false
      end
    end

    context "when the judge fails" do
      register_backend("failing", FailingBackend.new)

      around_each do |proc|
        proc.call
      ensure
        Feed::Judging.forget("failing")
        Feed::Queue.resume("failing")
      end

      let_create!(:feed, owner: actor, backend: "failing")
      let_create!(:object, named: hit, content: "<p>boom</p>")

      context "and the failure is transient" do
        before_each { FailingBackend.error = Feed::Backend::TransientError.new("judge unavailable") }

        it "records a transient failure" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::TRANSIENT)
        end

        it "records the failure's reason" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.reason)).to match(/judge unavailable/)
        end

        it "asks again later" do
          Feed::Judging.answer([question])
          expect(retry_for(hit).try(&.due_at)).to be_close(Feed::Judging::RETRY_DELAY.from_now, delta: 1.second)
        end

        it "asks again as backfill" do
          Feed::Judging.answer([question])
          expect(retry_for(hit).try(&.live)).to be_false
        end

        context "and the question is live" do
          before_each { question.assign(live: true).save }

          it "asks again as live" do
            Feed::Judging.answer([question])
            expect(retry_for(hit).try(&.live)).to be_true
          end
        end

        context "given another question in the batch" do
          let_create!(:object, named: other, content: "<p>something else</p>")
          let_create(:feed_question, named: second, feed: feed, object: other, batched: true)

          it "records a transient failure" do
            Feed::Judging.answer([question, second])
            expect(verdict_for(other).try(&.failure)).to eq(Feed::Verdict::TRANSIENT)
          end

          context "that is live" do
            before_each { second.assign(live: true).save }

            it "asks again as live" do
              Feed::Judging.answer([question, second])
              expect(retry_for(other).try(&.live)).to be_true
            end
          end
        end

        context "and the queue is full" do
          let_create!(:feed_question, named: nil)
          let_create!(:feed_question, named: nil)
          let_create!(:feed_question, named: nil)

          pre_condition { expect(Feed::Question.count(batched: false)).to be >= Feed::Queue.live_cap }

          it "asks again" do
            Feed::Judging.answer([question])
            expect(retry_for(hit)).not_to be_nil
          end
        end

        it "does not pause the judge before the limit is reached" do
          (Feed::Judging::FAILURES_BEFORE_PAUSE - 1).times { Feed::Judging.answer([question]) }
          expect(Feed::Queue.paused_until("failing")).to be_nil
        end

        context "when one batch fewer than the limit has failed" do
          before_each { (Feed::Judging::FAILURES_BEFORE_PAUSE - 1).times { Feed::Judging.answer([question]) } }

          it "pauses the judge after the next batch fails" do
            Feed::Judging.answer([question])
            expect(Feed::Queue.paused_until("failing")).to be_close(Feed::Judging::PAUSE.from_now, delta: 1.second)
          end

          it "asks again later about the batch" do
            Feed::Judging.answer([question])
            expect(retry_for(hit).try(&.due_at)).to be_close(Feed::Judging::RETRY_DELAY.from_now, delta: 1.second)
          end

          context "but the next batch succeeds" do
            before_each do
              hit.assign(content: "<p>fine</p>").save
              Feed::Judging.answer([question])
              hit.assign(content: "<p>boom</p>").save
            end

            it "does not pause the judge" do
              Feed::Judging.answer([question])
              expect(Feed::Queue.paused_until("failing")).to be_nil
            end
          end

          context "and the judge was paused before" do
            before_each { Feed::Judging.answer([question]) }

            it "pauses the judge again, for twice as long" do
              Feed::Judging.answer([question])
              expect(Feed::Queue.paused_until("failing")).to be_close((Feed::Judging::PAUSE * 2).from_now, delta: 1.second)
            end
          end

          context "and the judge was paused many times before" do
            before_each { 10.times { Feed::Judging.answer([question]) } }

            it "pauses the judge for no longer than the longest pause" do
              Feed::Judging.answer([question])
              expect(Feed::Queue.paused_until("failing")).to be_close(Feed::Judging::LONGEST_PAUSE.from_now, delta: 1.second)
            end
          end
        end
      end

      context "because the judge is unavailable" do
        let(retry_after) { nil.as(Time?) }

        before_each { FailingBackend.error = Feed::Backend::UnavailableError.new("unavailable", retry_after) }

        it "pauses the judge" do
          Feed::Judging.answer([question])
          expect(Feed::Queue.paused_until("failing")).to be_close(Feed::Judging::PAUSE.from_now, delta: 1.second)
        end

        it "keeps the question waiting, at its original time" do
          Feed::Judging.answer([question])
          expect(retry_for(hit).try(&.due_at)).to be_close(question.due_at, delta: 1.second)
        end

        context "and says to retry before the pause would end" do
          let(retry_after) { 1.minute.from_now.as(Time?) }

          it "pauses the judge until then" do
            Feed::Judging.answer([question])
            expect(Feed::Queue.paused_until("failing")).to eq(retry_after)
          end
        end

        context "and says to retry after the pause would end" do
          let(retry_after) { 1.hour.from_now.as(Time?) }

          it "does not lengthen the pause" do
            Feed::Judging.answer([question])
            expect(Feed::Queue.paused_until("failing")).to be_close(Feed::Judging::PAUSE.from_now, delta: 1.second)
          end
        end

        context "and says to retry in the past" do
          let(retry_after) { 1.minute.ago.as(Time?) }

          it "pauses the judge for the full pause" do
            Feed::Judging.answer([question])
            expect(Feed::Queue.paused_until("failing")).to be_close(Feed::Judging::PAUSE.from_now, delta: 1.second)
          end
        end
      end

      context "and the failure is permanent" do
        before_each { FailingBackend.error = Feed::Backend::PermanentError.new("judge misconfigured") }

        it "records a permanent failure" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::PERMANENT)
        end

        it "records the failure's reason" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.reason)).to match(/judge misconfigured/)
        end

        it "does not ask again" do
          Feed::Judging.answer([question])
          expect(retry_for(hit)).to be_nil
        end
      end

      context "and the failure is unclassified" do
        before_each { FailingBackend.error = Exception.new("judge crashed") }

        it "records a transient failure" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::TRANSIENT)
        end
      end
    end

    context "when the judge reports a failure" do
      register_backend("reporting", ReportingBackend.new)

      around_each do |proc|
        proc.call
      ensure
        Feed::Judging.forget("reporting")
      end

      let_create!(:feed, owner: actor, backend: "reporting")
      let_create!(:object, named: hit, content: "<p>boom</p>")

      context "and the failure is transient" do
        before_each { ReportingBackend.kind = :transient }

        it "records a transient failure" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::TRANSIENT)
        end

        it "records the failure's reason" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.reason)).to match(/post is unreadable/)
        end

        it "asks again later" do
          Feed::Judging.answer([question])
          expect(retry_for(hit).try(&.due_at)).to be_close(Feed::Judging::RETRY_DELAY.from_now, delta: 1.second)
        end

        it "asks again as backfill" do
          Feed::Judging.answer([question])
          expect(retry_for(hit).try(&.live)).to be_false
        end

        context "and the question is live" do
          before_each { question.assign(live: true).save }

          it "asks again as live" do
            Feed::Judging.answer([question])
            expect(retry_for(hit).try(&.live)).to be_true
          end
        end
      end

      context "and the failure is permanent" do
        before_each { ReportingBackend.kind = :permanent }

        it "records a permanent failure" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.failure)).to eq(Feed::Verdict::PERMANENT)
        end

        it "records the failure's reason" do
          Feed::Judging.answer([question])
          expect(verdict_for(hit).try(&.reason)).to match(/post is unreadable/)
        end

        it "does not ask again" do
          Feed::Judging.answer([question])
          expect(retry_for(hit)).to be_nil
        end
      end
    end
  end
end
