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
        expect(verdict.version).to eq(feed.version)
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

      context "when the policy is edited and the version bumped" do
        before_each do
          Feed::Judging.judge(feed)
          feed.assign(version: 2, params: JSON.parse(%({"keywords": {"any": ["gamma"]}})).as_h).save
        end

        it "re-judges all candidates" do
          expect(Feed::Judging.judge(feed)).to eq(2)
        end

        it "overwrites verdicts rather than accumulating them" do
          Feed::Judging.judge(feed)
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(2)
          expect(Feed::Verdict.count(feed_id: feed.id, version: 2)).to eq(2)
        end

        it "repopulates the feed under the new policy" do
          Feed::Judging.judge(feed)
          expect(materialized).to eq([{miss.iri, miss_arrival}])
        end

        it "drops rows a re-judge never re-reaches" do
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

      it "writes a verdict" do
        expect { Feed::Judging.judge_arrival(hit) }
          .to change { Feed::Verdict.count(feed_id: feed.id, object_iri: hit.iri) }.from(0).to(1)
      end

      it "includes the matching object at its arrival time" do
        Feed::Judging.judge_arrival(hit)
        verdict = Feed::Verdict.find(feed_id: feed.id, object_iri: hit.iri)
        expect(verdict.included).to be_true
        expect(verdict.version).to eq(feed.version)
        expect(verdict.position).to eq(arrival)
      end

      it "does not materialize the feed itself" do
        Feed::Judging.judge_arrival(hit)
        expect(materialized).to be_empty
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
