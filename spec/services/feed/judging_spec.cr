require "../../../src/services/feed/judging"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/feed/backend"
require "../../spec_helper/feed/queue"

private class CountingBackend < TestBackend
  class_property calls = 0

  def judge(feed : Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
    CountingBackend.calls += 1
    objects.map { Judgment.new(included: true) }
  end

  def validate_params(params : Hash(String, JSON::Any)) : Array(String)
    [] of String
  end
end

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

  def materialized(feed = self.feed)
    Ktistec.database.query_all(
      "SELECT to_iri, created_at FROM relationships WHERE type = ?",
      feed.feed_type, as: {String, Time})
  end

  def retry_for(object, feed = self.feed)
    Feed::Question.find?(version_id: feed.version_id, object_iri: object.iri, batched: false)
  end

  describe ".judge" do
    it "judges nothing" do
      expect(Feed::Judging.judge(feed)).to eq(0)
    end

    context "given objects" do
      let_create!(:object, named: hit, content: "<p>something alpha something</p>")
      let_create!(:object, named: miss, content: "<p>something gamma something</p>")

      it "judges the candidates" do
        expect(Feed::Judging.judge(feed)).to eq(2)
      end

      it "writes a verdict per candidate" do
        expect { Feed::Judging.judge(feed) }
          .to change { Feed::Verdict.count(version_id: feed.version_id) }.from(0).to(2)
      end

      it "includes the matching object" do
        Feed::Judging.judge(feed)
        verdict = Feed::Verdict.find(version_id: feed.version_id, object_iri: hit.iri)
        expect(verdict.included).to be_true
        expect(verdict.reason).to match(/alpha/)
      end

      it "excludes the non-matching object" do
        Feed::Judging.judge(feed)
        verdict = Feed::Verdict.find(version_id: feed.version_id, object_iri: miss.iri)
        expect(verdict.included).to be_false
      end

      it "materializes the matching object at its creation time" do
        Feed::Judging.judge(feed)
        expect(materialized).to eq([{hit.iri, hit.created_at}])
      end

      it "judges nothing on a second run" do
        Feed::Judging.judge(feed)
        expect(Feed::Judging.judge(feed)).to eq(0)
      end

      it "judges candidates in batches, newest first" do
        expect(Feed::Judging.judge(feed, limit: 1)).to eq(1)
        expect(Feed::Verdict.count(version_id: feed.version_id, object_iri: miss.iri)).to eq(1)
        expect(Feed::Judging.judge(feed, limit: 1)).to eq(1)
        expect(Feed::Verdict.count(version_id: feed.version_id, object_iri: hit.iri)).to eq(1)
        expect(Feed::Judging.judge(feed, limit: 1)).to eq(0)
      end

      context "when the match limit is reached" do
        # "something" matches both objects
        let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["something"]}})).as_h)

        pre_condition { expect(Feed::Candidates.candidates_for(feed).size).to eq(2) }

        it "judges only the first candidate" do
          expect(Feed::Judging.judge(feed, match_limit: 1)).to eq(1)
        end

        it "writes a verdict only for the judged candidate" do
          expect { Feed::Judging.judge(feed, match_limit: 1) }
            .to change { Feed::Verdict.count(version_id: feed.version_id) }.from(0).to(1)
        end

        it "judges the unjudged candidate on a second run" do
          Feed::Judging.judge(feed, match_limit: 1)
          expect(Feed::Judging.judge(feed, match_limit: 1)).to eq(1)
        end
      end

      context "when the policy is edited" do
        before_each do
          Feed::Judging.judge(feed)
          feed.assign(params: JSON.parse(%({"keywords": {"any": ["gamma"]}})).as_h).save
        end

        pre_condition { expect(Feed::Verdict.count(version_id: feed.version_id)).to eq(0) }

        it "re-judges all candidates" do
          expect(Feed::Judging.judge(feed)).to eq(2)
        end

        it "writes fresh verdicts" do
          Feed::Judging.judge(feed)
          expect(Feed::Verdict.count(version_id: feed.version_id)).to eq(2)
        end

        it "repopulates the feed under the new policy" do
          Feed::Judging.judge(feed)
          expect(materialized).to eq([{miss.iri, miss.created_at}])
        end
      end

      context "given another feed on the same version" do
        let_create!(:feed, named: other, owner: actor, params: feed.params)

        before_each { Feed::Judging.judge(other) }

        pre_condition { expect(other.version_id).to eq(feed.version_id) }

        it "judges nothing" do
          expect(Feed::Judging.judge(feed)).to eq(0)
        end

        it "materializes the matching object" do
          expect(materialized).to eq([{hit.iri, hit.created_at}])
        end
      end
    end

    context "given a non-positive limit" do
      it "raises an error" do
        expect { Feed::Judging.judge(feed, limit: 0) }.to raise_error(ArgumentError, "limit must be positive")
      end
    end

    context "when the judge fails on a candidate" do
      register_backend("failing", FailingBackend.new)

      let_create!(:feed, owner: actor, backend: "failing")
      let_create!(:object, named: fine, content: "<p>fine</p>")
      let_create!(:object, named: boom, content: "<p>boom</p>")

      def verdict_for(object)
        Feed::Verdict.find(version_id: feed.version_id, object_iri: object.iri)
      end

      pre_condition { expect(Feed::Candidates.candidates_for(feed).map(&.iri)).to eq([boom.iri, fine.iri]) }

      it "goes on to judge the next candidate" do
        Feed::Judging.judge(feed)
        expect(verdict_for(fine).included).to be_true
      end

      context "and the failure is transient" do
        before_each { FailingBackend.error = Feed::Backend::TransientError.new("judge unavailable") }

        it "records a transient failure" do
          Feed::Judging.judge(feed)
          expect(verdict_for(boom).failure).to eq(Feed::Verdict::TRANSIENT)
        end

        it "records the failure's reason" do
          Feed::Judging.judge(feed)
          expect(verdict_for(boom).reason).to match(/judge unavailable/)
        end

        it "asks again as backfill" do
          Feed::Judging.judge(feed)
          expect(retry_for(boom).try(&.live)).to be_false
        end
      end

      context "and the failure is permanent" do
        before_each { FailingBackend.error = Feed::Backend::PermanentError.new("judge misconfigured") }

        it "records a permanent failure" do
          Feed::Judging.judge(feed)
          expect(verdict_for(boom).failure).to eq(Feed::Verdict::PERMANENT)
        end

        it "records the failure's reason" do
          Feed::Judging.judge(feed)
          expect(verdict_for(boom).reason).to match(/judge misconfigured/)
        end

        it "does not ask again" do
          Feed::Judging.judge(feed)
          expect(Feed::Question.count).to eq(0)
        end
      end

      context "and the failure is unclassified" do
        before_each { FailingBackend.error = Exception.new("judge crashed") }

        it "records a transient failure" do
          Feed::Judging.judge(feed)
          expect(verdict_for(boom).failure).to eq(Feed::Verdict::TRANSIENT)
        end
      end
    end
  end

  describe ".rejudge_contents" do
    let_create!(:feed, named: source, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
    let_create!(:feed, named: target, owner: actor, params: JSON.parse(%({"keywords": {"any": ["beta"]}})).as_h)

    context "given included members of the source feed" do
      let_build(:object, named: kept, content: "<p>alpha beta</p>")
      let_build(:object, named: dropped, content: "<p>alpha gamma</p>")
      let_create!(:feed_verdict, named: nil, feed: source, object: kept, included: true)
      let_create!(:feed_verdict, named: nil, feed: source, object: dropped, included: true)

      it "seeds the surviving member" do
        Feed::Judging.rejudge_contents(source, target)
        expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: kept.iri).try(&.included)).to be_true
      end

      it "materializes the surviving member at its creation time" do
        Feed::Judging.rejudge_contents(source, target)
        expect(materialized(target)).to eq([{kept.iri, kept.created_at}])
      end

      context "and another feed on the target's version" do
        let_create!(:feed, named: other, owner: actor, params: target.params)

        pre_condition { expect(other.version_id).to eq(target.version_id) }

        it "materializes the surviving member in the other feed" do
          Feed::Judging.rejudge_contents(source, target)
          expect(materialized(other)).to eq([{kept.iri, kept.created_at}])
        end
      end

      it "returns the number seeded" do
        expect(Feed::Judging.rejudge_contents(source, target)).to eq(1)
      end

      it "excludes the dropped member" do
        Feed::Judging.rejudge_contents(source, target)
        expect(Feed::Verdict.find(version_id: target.version_id, object_iri: dropped.iri).excluded?).to be_true
      end

      it "leaves the source untouched" do
        expect { Feed::Judging.rejudge_contents(source, target) }
          .not_to change { Feed::Verdict.count(version_id: source.version_id) }.from(2)
      end

      context "and an excluded member the target's criteria would match" do
        let_build(:object, named: excluded, content: "<p>beta</p>")
        let_create!(:feed_verdict, named: nil, feed: source, object: excluded, included: false)

        pre_condition { expect(Feed::Verdict.find(version_id: source.version_id, object_iri: excluded.iri).included).to be_false }

        it "does not include the excluded member" do
          Feed::Judging.rejudge_contents(source, target)
          expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: kept.iri)).not_to be_nil
          expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: excluded.iri)).to be_nil
        end
      end

      context "and a member whose object was deleted" do
        let_build(:object, named: deleted, content: "<p>alpha beta</p>")
        let_create!(:feed_verdict, named: nil, feed: source, object: deleted, included: true)

        before_each { deleted.delete! }

        pre_condition { expect(Feed::Verdict.find(version_id: source.version_id, object_iri: deleted.iri).included).to be_true }

        it "does not include the deleted member" do
          Feed::Judging.rejudge_contents(source, target)
          expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: kept.iri)).not_to be_nil
          expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: deleted.iri)).to be_nil
        end
      end

      context "and a member whose object is not visible" do
        let_build(:object, named: hidden, content: "<p>alpha beta</p>", visible: false)
        let_create!(:feed_verdict, named: nil, feed: source, object: hidden, included: true)

        pre_condition { expect(Feed::Verdict.find(version_id: source.version_id, object_iri: hidden.iri).included).to be_true }

        it "does not include the hidden member" do
          Feed::Judging.rejudge_contents(source, target)
          expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: kept.iri)).not_to be_nil
          expect(Feed::Verdict.find?(version_id: target.version_id, object_iri: hidden.iri)).to be_nil
        end
      end

      # in draft->publish the target already holds its own
      # preview-window verdicts, so a survivor can arrive already
      # having a target verdict; rejudge must upsert it, not add a
      # second row..
      context "and the target already has a verdict for the survivor" do
        let_create!(:feed_verdict, named: nil, feed: target, object: kept, included: true)

        pre_condition { expect(Feed::Verdict.count(version_id: target.version_id, object_iri: kept.iri)).to eq(1) }

        it "does not duplicate the survivor's verdict" do
          expect { Feed::Judging.rejudge_contents(source, target) }
            .not_to change { Feed::Verdict.count(version_id: target.version_id, object_iri: kept.iri) }.from(1)
        end
      end
    end

    context "when the edit keeps the feed's version" do
      register_backend("counting", CountingBackend.new)

      let_create!(:feed, named: source, owner: actor, backend: "counting")
      let_create!(:feed, named: target, owner: actor, backend: "counting")
      let_create!(:feed_verdict, named: nil, feed: source, included: true)

      pre_condition { expect(target.version_id).to eq(source.version_id) }

      it "does not judge the contents again" do
        expect { Feed::Judging.rejudge_contents(source, target) }.not_to change { CountingBackend.calls }
      end
    end

    context "when the judge fails on a member" do
      register_backend("failing", FailingBackend.new)

      let_create!(:feed, named: target, owner: actor, backend: "failing")
      let_build(:object, named: boom, content: "<p>boom</p>")
      let_create!(:feed_verdict, named: nil, feed: source, object: boom, included: true)

      it "records the failure" do
        Feed::Judging.rejudge_contents(source, target)
        expect(Feed::Verdict.find(version_id: target.version_id, object_iri: boom.iri).failed?).to be_true
      end
    end
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

    it "puts the matching object in the feed" do
      Feed::Judging.answer(question)
      expect(materialized).to eq([{hit.iri, hit.created_at}])
    end

    context "given another feed on the same version" do
      let_create!(:feed, named: other, owner: actor, params: feed.params)

      pre_condition { expect(other.version_id).to eq(feed.version_id) }

      it "puts the matching object in the other feed" do
        Feed::Judging.answer(question)
        expect(materialized(other)).to eq([{hit.iri, hit.created_at}])
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

    context "when the judge fails" do
      register_backend("failing", FailingBackend.new)

      let_create!(:feed, owner: actor, backend: "failing")
      let_create!(:object, named: hit, content: "<p>boom</p>")

      context "and the failure is transient" do
        before_each { FailingBackend.error = Feed::Backend::TransientError.new("judge unavailable") }

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
    end
  end

  describe ".judge_arrival" do
    around_each do |proc|
      saved = Rules::View.registry.dup
      begin
        proc.call
      ensure
        Rules::View.registry.clear
        Rules::View.registry.concat(saved)
      end
    end

    let_build(:object, named: hit, content: "<p>something alpha something</p>")
    let_create(:create, named: hit_create, object: hit)
    let_build(:object, named: miss, content: "<p>something gamma something</p>")
    let_create(:create, named: miss_create, object: miss)

    before_each do
      put_in_inbox(actor, hit_create)
      put_in_inbox(actor, miss_create)
    end

    pre_condition do
      expect(Feed::Verdict.count(version_id: feed.version_id, object_iri: hit.iri)).to eq(0)
      expect(Feed::Verdict.count(version_id: feed.version_id, object_iri: miss.iri)).to eq(0)
    end

    context "when the feed is not registered" do
      pre_condition { expect(Feed::Candidates.arrival_for(feed, hit)).not_to be_nil }

      it "writes no verdict" do
        expect { Feed::Judging.judge_arrival(hit) }
          .not_to change { Feed::Verdict.count(version_id: feed.version_id) }.from(0)
      end
    end

    context "when the feed is registered" do
      before_each { Rules::Feeds.register(feed) }

      it "does not materialize the feed itself" do
        Feed::Judging.judge_arrival(hit)
        expect(materialized).to be_empty
      end

      it "writes a verdict" do
        expect { Feed::Judging.judge_arrival(hit) }
          .to change { Feed::Verdict.count(version_id: feed.version_id, object_iri: hit.iri) }.from(0).to(1)
      end

      it "includes the matching object" do
        Feed::Judging.judge_arrival(hit)
        verdict = Feed::Verdict.find(version_id: feed.version_id, object_iri: hit.iri)
        expect(verdict.included).to be_true
      end

      context "given a matching object whose author is deleted" do
        before_each { hit.attributed_to.delete! }

        it "writes a verdict" do
          expect { Feed::Judging.judge_arrival(hit) }
            .to change { Feed::Verdict.count(version_id: feed.version_id, object_iri: hit.iri) }.from(0).to(1)
        end
      end

      context "given a matching object whose author is blocked" do
        before_each { hit.attributed_to.block! }

        it "writes a verdict" do
          expect { Feed::Judging.judge_arrival(hit) }
            .to change { Feed::Verdict.count(version_id: feed.version_id, object_iri: hit.iri) }.from(0).to(1)
        end
      end

      context "given a matching object that is not visible" do
        let_build(:object, named: hidden, content: "<p>something alpha something</p>", visible: false)
        let_create!(:feed_verdict, named: nil, feed: feed, object: hidden, included: true)

        pre_condition { expect(Feed::Verdict.find(version_id: feed.version_id, object_iri: hidden.iri).included).to be_true }

        it "leaves the verdict included" do
          Feed::Judging.judge_arrival(hidden)
          expect(Feed::Verdict.find(version_id: feed.version_id, object_iri: hidden.iri).included).to be_true
        end
      end

      context "given a non-matching object" do
        it "writes a verdict" do
          expect { Feed::Judging.judge_arrival(miss) }
            .to change { Feed::Verdict.count(version_id: feed.version_id, object_iri: miss.iri) }.from(0).to(1)
        end

        it "excludes the non-matching object" do
          Feed::Judging.judge_arrival(miss)
          verdict = Feed::Verdict.find(version_id: feed.version_id, object_iri: miss.iri)
          expect(verdict.included).to be_false
        end
      end
    end

    context "when two registered feeds share a version" do
      register_backend("counting", CountingBackend.new)

      let_create(:feed, named: one, owner: actor, backend: "counting")
      let_create(:feed, named: two, owner: actor, backend: "counting")

      before_each do
        Rules::Feeds.register(one)
        Rules::Feeds.register(two)
      end

      pre_condition { expect(one.version_id).to eq(two.version_id) }

      it "judges the post once, not once per feed" do
        expect { Feed::Judging.judge_arrival(hit) }.to change { CountingBackend.calls }.by(1)
      end
    end

    context "when a registered feed's judge fails" do
      register_backend("failing", FailingBackend.new)

      let_create(:feed, named: failing, owner: actor, backend: "failing")
      let_build(:object, named: boom, content: "<p>boom</p>")
      let_create(:create, named: boom_create, object: boom)

      # saving a post judges its arrival, so save every post before
      # registering the feed.
      before_each do
        put_in_inbox(actor, boom_create)
        Rules::Feeds.register(failing)
      end

      def verdict_for(object)
        Feed::Verdict.find(version_id: failing.version_id, object_iri: object.iri)
      end

      it "records the failure" do
        Feed::Judging.judge_arrival(boom)
        expect(verdict_for(boom).failed?).to be_true
      end

      context "and the failure is transient" do
        before_each { FailingBackend.error = Feed::Backend::TransientError.new("judge unavailable") }

        it "asks again later as live" do
          Feed::Judging.judge_arrival(boom)
          expect(retry_for(boom, failing).try(&.live)).to be_true
        end
      end

      context "given a failure for a post the judge can answer" do
        let_create!(:feed_verdict, named: nil, feed: failing, object_iri: hit.iri, included: false, failure: Feed::Verdict::TRANSIENT)

        it "replaces the failure" do
          Feed::Judging.judge_arrival(hit)
          expect(verdict_for(hit).included).to be_true
        end
      end
    end
  end
end
