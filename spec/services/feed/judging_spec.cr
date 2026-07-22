require "../../../src/services/feed/judging"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Judging do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

  def materialized
    Ktistec.database.query_all(
      "SELECT to_iri, created_at FROM relationships WHERE type = ?",
      feed.feed_type, as: {String, Time})
  end

  describe ".judge" do
    it "judges nothing" do
      expect(Feed::Judging.judge(feed)).to eq(0)
    end

    context "given posts in the owner's inbox" do
      let_build(:object, named: hit, content: "<p>something alpha something</p>")
      let_build(:object, named: miss, content: "<p>something gamma something</p>")
      let_create(:create, named: hit_create, object: hit)
      let_create(:create, named: miss_create, object: miss)
      let!(hit_arrival) { put_in_inbox(actor, hit_create).created_at }
      let!(miss_arrival) { put_in_inbox(actor, miss_create).created_at }

      it "judges the candidates" do
        expect(Feed::Judging.judge(feed)).to eq(2)
      end

      it "writes a verdict per candidate" do
        expect { Feed::Judging.judge(feed) }
          .to change { Feed::Verdict.count(feed_id: feed.id) }.from(0).to(2)
      end

      it "includes the matching post" do
        Feed::Judging.judge(feed)
        verdict = Feed::Verdict.find(feed_id: feed.id, object_iri: hit.iri)
        expect(verdict.included).to be_true
        expect(verdict.reason).to match(/alpha/)
        expect(verdict.position).to eq(hit_arrival)
      end

      it "excludes the non-matching post" do
        Feed::Judging.judge(feed)
        verdict = Feed::Verdict.find(feed_id: feed.id, object_iri: miss.iri)
        expect(verdict.included).to be_false
      end

      it "materializes the matching post at its arrival time" do
        Feed::Judging.judge(feed)
        expect(materialized).to eq([{hit.iri, hit_arrival}])
      end

      it "judges nothing on a second run" do
        Feed::Judging.judge(feed)
        expect(Feed::Judging.judge(feed)).to eq(0)
      end

      it "judges candidates in batches ordered by arrival" do
        expect(Feed::Judging.judge(feed, limit: 1)).to eq(1)
        expect(Feed::Verdict.count(feed_id: feed.id, object_iri: miss.iri)).to eq(1)
        expect(Feed::Judging.judge(feed, limit: 1)).to eq(1)
        expect(Feed::Verdict.count(feed_id: feed.id, object_iri: hit.iri)).to eq(1)
        expect(Feed::Judging.judge(feed, limit: 1)).to eq(0)
      end

      context "when the match limit is reached" do
        # "something" matches both posts
        let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["something"]}})).as_h)

        pre_condition { expect(Feed::Candidates.candidates_for(feed).size).to eq(2) }

        it "judges only the first candidate" do
          expect(Feed::Judging.judge(feed, match_limit: 1)).to eq(1)
        end

        it "writes a verdict only for the judged candidate" do
          expect { Feed::Judging.judge(feed, match_limit: 1) }
            .to change { Feed::Verdict.count(feed_id: feed.id) }.from(0).to(1)
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

        pre_condition do
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
          expect(materialized).to be_empty
        end

        it "re-judges all candidates" do
          expect(Feed::Judging.judge(feed)).to eq(2)
        end

        it "writes fresh verdicts" do
          Feed::Judging.judge(feed)
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(2)
        end

        it "repopulates the feed under the new policy" do
          Feed::Judging.judge(feed)
          expect(materialized).to eq([{miss.iri, miss_arrival}])
        end

        it "leaves no stale rows after a bounded re-judge" do
          Feed::Judging.judge(feed, match_limit: 1)
          expect(materialized).to eq([{miss.iri, miss_arrival}])
        end
      end
    end

    context "given an unregistered backend" do
      before_each { feed.assign(backend: "missing").save(skip_validation: true) }

      it "raises an error" do
        expect { Feed::Judging.judge(feed) }.to raise_error(/is not a registered backend/)
      end
    end

    context "given a non-positive limit" do
      it "raises an error" do
        expect { Feed::Judging.judge(feed, limit: 0) }.to raise_error(ArgumentError, "limit must be positive")
      end
    end
  end

  describe ".rejudge_contents" do
    let_create!(:feed, named: source, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
    let_create!(:feed, named: target, owner: actor, params: JSON.parse(%({"keywords": {"any": ["beta"]}})).as_h)

    def materialized_in(feed)
      Ktistec.database.query_all(
        "SELECT to_iri, created_at FROM relationships WHERE type = ?",
        feed.feed_type, as: {String, Time})
    end

    context "given included members of the source feed" do
      let_build(:object, named: kept, content: "<p>alpha beta</p>")
      let_build(:object, named: dropped, content: "<p>alpha gamma</p>")
      let(kept_position) { Time.utc(2026, 1, 2) }
      let_create!(:feed_verdict, named: nil, feed: source, object: kept, included: true, position: kept_position)
      let_create!(:feed_verdict, named: nil, feed: source, object: dropped, included: true)

      it "seeds the surviving member" do
        Feed::Judging.rejudge_contents(source, target)
        expect(Feed::Verdict.find?(feed_id: target.id, object_iri: kept.iri).try(&.included)).to be_true
      end

      it "materializes the surviving member at its arrival position" do
        Feed::Judging.rejudge_contents(source, target)
        expect(materialized_in(target)).to eq([{kept.iri, kept_position}])
      end

      it "returns the number seeded" do
        expect(Feed::Judging.rejudge_contents(source, target)).to eq(1)
      end

      it "writes only included verdicts" do
        Feed::Judging.rejudge_contents(source, target)
        expect(Feed::Verdict.count(feed_id: target.id)).to eq(1)
      end

      it "does not include the dropped member" do
        Feed::Judging.rejudge_contents(source, target)
        expect(Feed::Verdict.find?(feed_id: target.id, object_iri: dropped.iri)).to be_nil
      end

      it "leaves the source untouched" do
        expect { Feed::Judging.rejudge_contents(source, target) }
          .not_to change { Feed::Verdict.count(feed_id: source.id) }.from(2)
      end

      context "and an excluded member the target's criteria would match" do
        let_build(:object, named: excluded, content: "<p>beta</p>")
        let_create!(:feed_verdict, named: nil, feed: source, object: excluded, included: false)

        pre_condition { expect(Feed::Verdict.find(feed_id: source.id, object_iri: excluded.iri).included).to be_false }

        it "does not include the excluded member" do
          Feed::Judging.rejudge_contents(source, target)
          expect(Feed::Verdict.find?(feed_id: target.id, object_iri: kept.iri)).not_to be_nil
          expect(Feed::Verdict.find?(feed_id: target.id, object_iri: excluded.iri)).to be_nil
        end
      end

      context "and a member whose object was deleted" do
        let_build(:object, named: deleted, content: "<p>alpha beta</p>")
        let_create!(:feed_verdict, named: nil, feed: source, object: deleted, included: true)

        before_each { deleted.delete! }

        pre_condition { expect(Feed::Verdict.find(feed_id: source.id, object_iri: deleted.iri).included).to be_true }

        it "does not include the deleted member" do
          Feed::Judging.rejudge_contents(source, target)
          expect(Feed::Verdict.find?(feed_id: target.id, object_iri: kept.iri)).not_to be_nil
          expect(Feed::Verdict.find?(feed_id: target.id, object_iri: deleted.iri)).to be_nil
        end
      end

      # in draft->publish the target already holds its own
      # preview-window verdicts, so a survivor can arrive already
      # having a target verdict; rejudge must upsert it, not add a
      # second row..
      context "and the target already has a verdict for the survivor" do
        let(stale_position) { Time.utc(2020, 1, 1) }
        let_create!(:feed_verdict, named: nil, feed: target, object: kept, included: true, position: stale_position)

        pre_condition { expect(Feed::Verdict.count(feed_id: target.id, object_iri: kept.iri)).to eq(1) }

        it "does not duplicate the survivor's verdict" do
          expect { Feed::Judging.rejudge_contents(source, target) }
            .not_to change { Feed::Verdict.count(feed_id: target.id, object_iri: kept.iri) }.from(1)
        end

        it "overwrites the position with the source's arrival" do
          Feed::Judging.rejudge_contents(source, target)
          expect(Feed::Verdict.find(feed_id: target.id, object_iri: kept.iri).position).to eq(kept_position)
        end
      end
    end

    context "given an unregistered target backend" do
      before_each { target.assign(backend: "missing").save(skip_validation: true) }

      it "raises an error" do
        expect { Feed::Judging.rejudge_contents(source, target) }.to raise_error(/is not a registered backend/)
      end
    end
  end

  describe ".backfill" do
    let(floor) { Time.utc(1970, 1, 1) }
    let(cursor) { nil }
    let(limit) { 10 }

    subject { Feed::Judging.backfill(feed, floor, cursor, limit) }

    it "scans nothing" do
      expect(subject.scanned).to eq(0)
    end

    it "reports no cursor" do
      expect(subject.cursor).to be_nil
    end

    it "is done" do
      expect(subject.done).to be_true
    end

    context "given posts in the owner's inbox" do
      let_build(:object, named: hit, content: "<p>something alpha something</p>")
      let_build(:object, named: miss, content: "<p>something gamma something</p>")
      let_create(:create, named: hit_create, object: hit)
      let_create(:create, named: miss_create, object: miss)
      let!(hit_row) { put_in_inbox(actor, hit_create) }
      let!(miss_row) { put_in_inbox(actor, miss_create) }

      it "scans both posts" do
        expect(subject.scanned).to eq(2)
      end

      it "reports the last row scanned as the cursor" do
        expect(subject.cursor).to eq(hit_row.id)
      end

      it "counts the matching post" do
        expect(subject.included).to eq(1)
      end

      it "writes a verdict for the matching post" do
        subject
        expect(Feed::Verdict.find(feed_id: feed.id, object_iri: hit.iri).included).to be_true
      end

      # only `included` verdicts are written -- a verdict for every
      # post the owner ever received, for every feed they own, is what
      # the backfill must not write.
      it "writes no verdict for the non-matching post" do
        subject
        expect(Feed::Verdict.find?(feed_id: feed.id, object_iri: miss.iri)).to be_nil
      end

      it "materializes the matching post at its arrival time" do
        subject
        expect(materialized).to eq([{hit.iri, hit_row.created_at}])
      end

      context "when the batch is truncated" do
        let(limit) { 1 }

        it "reports the last row scanned as the cursor" do
          expect(subject.cursor).to eq(miss_row.id)
        end

        it "is not done" do
          expect(subject.done).to be_false
        end
      end

      context "when the floor is above the oldest arrival" do
        let(floor) { miss_row.created_at }

        it "does not scan the post below the floor" do
          expect(subject.scanned).to eq(1)
        end

        it "writes no verdict for it" do
          subject
          expect(Feed::Verdict.find?(feed_id: feed.id, object_iri: hit.iri)).to be_nil
        end
      end

      context "when the whole batch is below the floor" do
        let(floor) { miss_row.created_at + 1.second }

        it "scans nothing" do
          expect(subject.scanned).to eq(0)
        end

        it "is done" do
          expect(subject.done).to be_true
        end
      end

      context "and the matching post arrives again" do
        let_create(:announce, named: hit_announce, object: hit)
        let!(hit_announce_row) { put_in_inbox(actor, hit_announce) }

        it "materializes it at its earliest arrival" do
          subject
          expect(materialized).to eq([{hit.iri, hit_row.created_at}])
        end

        it "judges it once" do
          expect(subject.scanned).to eq(2)
        end

        context "but its earliest arrival is below the floor" do
          let(floor) { hit_announce_row.created_at }

          it "writes no verdict for it" do
            subject
            expect(Feed::Verdict.find?(feed_id: feed.id, object_iri: hit.iri)).to be_nil
          end
        end
      end
    end

    context "given an unregistered backend" do
      before_each { feed.assign(backend: "missing").save(skip_validation: true) }

      it "raises an error" do
        expect { subject }.to raise_error(/is not a registered backend/)
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
    let!(arrival) { put_in_inbox(actor, hit_create).created_at }

    context "when the feed is not registered" do
      pre_condition { expect(Feed::Candidates.arrival_for(feed, hit)).not_to be_nil }

      it "writes no verdict" do
        expect { Feed::Judging.judge_arrival(hit) }
          .not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(0)
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
          .to change { Feed::Verdict.count(feed_id: feed.id, object_iri: hit.iri) }.from(0).to(1)
      end

      it "includes the matching object at its arrival time" do
        Feed::Judging.judge_arrival(hit)
        verdict = Feed::Verdict.find(feed_id: feed.id, object_iri: hit.iri)
        expect(verdict.included).to be_true
        expect(verdict.position).to eq(arrival)
      end

      context "given a matching object whose author is deleted" do
        before_each { hit.attributed_to.delete! }

        pre_condition { expect(hit.deleted?).to be_false }

        it "writes no verdict" do
          expect { Feed::Judging.judge_arrival(hit) }
            .not_to change { Feed::Verdict.count(feed_id: feed.id, object_iri: hit.iri) }.from(0)
        end
      end

      context "given a matching object whose author is blocked" do
        before_each { hit.attributed_to.block! }

        it "writes a verdict" do
          expect { Feed::Judging.judge_arrival(hit) }
            .to change { Feed::Verdict.count(feed_id: feed.id, object_iri: hit.iri) }.from(0).to(1)
        end
      end

      context "given a non-matching object" do
        let_build(:object, named: miss, content: "<p>something gamma something</p>")
        let_create(:create, named: miss_create, object: miss)
        before_each { put_in_inbox(actor, miss_create) }

        it "writes a verdict" do
          expect { Feed::Judging.judge_arrival(miss) }
            .to change { Feed::Verdict.count(feed_id: feed.id, object_iri: miss.iri) }.from(0).to(1)
        end

        it "excludes the non-matching object" do
          Feed::Judging.judge_arrival(miss)
          verdict = Feed::Verdict.find(feed_id: feed.id, object_iri: miss.iri)
          expect(verdict.included).to be_false
        end
      end
    end
  end
end
