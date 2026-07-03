require "../../../src/services/feed/judging"
require "../../../src/services/feed/backend/keyword"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Judging do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": ["alpha"]})).as_h)

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

      context "when the invoker is swapped" do
        around_each do |proc|
          invoker = Feed::Backend.invoker
          Feed::Backend.invoker = ->(_backend : Feed::Backend, _feed : Feed, objects : Array(ActivityPub::Object)) do
            objects.map { Feed::Backend::Judgment.new(included: true, reason: "swapped") }
          end
          begin
            proc.call
          ensure
            Feed::Backend.invoker = invoker
          end
        end

        it "judges via the seam, not the backend" do
          Feed::Judging.judge(feed)
          expect(Feed::Verdict.where(feed_id: feed.id).map(&.reason)).to eq(["swapped", "swapped"])
        end
      end

      context "when the policy is edited and the version bumped" do
        before_each do
          Feed::Judging.judge(feed)
          feed.assign(version: 2, params: JSON.parse(%({"keywords": ["gamma"]})).as_h).save
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
      end
    end

    context "given an unregistered backend" do
      before_each { feed.assign(backend: "missing").save(skip_validation: true) }

      it "raises an error" do
        expect { Feed::Judging.judge(feed) }.to raise_error(/is not a registered backend/)
      end
    end
  end
end
