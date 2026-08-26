require "../../../src/models/task/collect_feed_orphans"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::CollectFeedOrphans do
  setup_spec

  def materialized_count(feed)
    Ktistec.database.scalar(
      "SELECT count(*) FROM relationships WHERE from_iri = ? AND type = ?",
      feed.owner_iri, feed.feed_type,
    ).as(Int64)
  end

  describe "#perform" do
    context "given a feed holding an object" do
      let_build(:actor)
      let_build(:object, attributed_to: actor)
      let_create!(:feed, draft: false)
      let_create!(:feed_verdict, feed: feed, object: object, included: true)

      before_each { put_in_feed(feed, object) }

      pre_condition { expect(materialized_count(feed)).to eq(1) }

      it "does not delete the verdict" do
        expect { subject.perform }.not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
      end

      it "does not delete the materialized row" do
        expect { subject.perform }.not_to change { materialized_count(feed) }.from(1)
      end

      context "and the object is deleted" do
        before_each { object.delete! }

        pre_condition do
          expect(ActivityPub::Object.find?(iri: object.iri, include_deleted: true)).not_to be_nil
        end

        it "does not delete the verdict" do
          expect { subject.perform }.not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
        end

        it "does not delete the materialized row" do
          expect { subject.perform }.not_to change { materialized_count(feed) }.from(1)
        end
      end

      context "and the object's author is deleted" do
        before_each { actor.delete! }

        pre_condition do
          expect(ActivityPub::Object.find?(iri: object.iri, include_deleted: true)).not_to be_nil
        end

        it "does not delete the verdict" do
          expect { subject.perform }.not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
        end

        it "does not delete the materialized row" do
          expect { subject.perform }.not_to change { materialized_count(feed) }.from(1)
        end
      end

      context "and the object no longer exists" do
        before_each { object.destroy }

        pre_condition { expect(ActivityPub::Object.find?(iri: object.iri, include_deleted: true)).to be_nil }

        it "deletes the verdict" do
          expect { subject.perform }.to change { Feed::Verdict.count(feed_id: feed.id) }.from(1).to(0)
        end

        it "deletes the materialized row" do
          expect { subject.perform }.to change { materialized_count(feed) }.from(1).to(0)
        end

        context "and a second held object no longer exists either" do
          let_build(:object, named: another, attributed_to: actor)
          let_create!(:feed_verdict, named: nil, feed: feed, object: another, included: true)

          before_each { another.destroy }

          it "deletes both verdicts" do
            expect { subject.perform }.to change { Feed::Verdict.count(feed_id: feed.id) }.from(2).to(0)
          end
        end

        context "and a second feed holds the same object" do
          let_create!(:feed, named: other, draft: false)
          let_create!(:feed_verdict, named: nil, feed: other, object: object, included: true)

          it "deletes the second feed's verdict" do
            expect { subject.perform }.to change { Feed::Verdict.count(feed_id: other.id) }.from(1).to(0)
          end
        end
      end
    end

    it "sets the next attempt at" do
      expect { subject.perform }.to change { subject.next_attempt_at }.from(nil)
    end

    context "when a sweep has already run" do
      let_build(:object)
      let_create!(:feed, draft: false)
      let_create!(:feed_verdict, feed: feed, object: object, included: true)

      before_each { subject.perform }

      pre_condition { expect(subject.state.cursor).to eq(feed_verdict.id) }

      context "and the object no longer exists" do
        before_each { object.destroy }

        it "collects it on the next sweep" do
          expect { subject.perform }.to change { Feed::Verdict.count(feed_id: feed.id) }.from(1).to(0)
        end
      end
    end
  end
end
