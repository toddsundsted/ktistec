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

        it "deletes the verdict" do
          expect { subject.perform }.to change { Feed::Verdict.count(feed_id: feed.id) }.from(1).to(0)
        end

        it "deletes the materialized row" do
          expect { subject.perform }.to change { materialized_count(feed) }.from(1).to(0)
        end

        context "and a second held object is deleted too" do
          let_build(:object, named: another, attributed_to: actor)
          let_create!(:feed_verdict, named: nil, feed: feed, object: another, included: true)

          before_each { another.delete! }

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

        context "but the object was deleted before the previous run" do
          before_each do
            subject.assign(last_attempt_at: object.deleted_at.not_nil! + 1.day).save
          end

          it "does not delete the verdict" do
            expect { subject.perform }.not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
          end

          it "does not delete the materialized row" do
            expect { subject.perform }.not_to change { materialized_count(feed) }.from(1)
          end
        end

        context "but the object was deleted before the task's lookback" do
          before_each do
            object.update_property(:deleted_at, subject.created_at - Task::CollectFeedOrphans::SWEEP_LOOKBACK - 1.day)
          end

          it "does not delete the verdict" do
            expect { subject.perform }.not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
          end

          it "does not delete the materialized row" do
            expect { subject.perform }.not_to change { materialized_count(feed) }.from(1)
          end
        end
      end

      context "and the object's author is deleted" do
        before_each { actor.delete! }

        it "deletes the verdict" do
          expect { subject.perform }.to change { Feed::Verdict.count(feed_id: feed.id) }.from(1).to(0)
        end

        it "deletes the materialized row" do
          expect { subject.perform }.to change { materialized_count(feed) }.from(1).to(0)
        end

        context "but the author was deleted before the previous run" do
          before_each { subject.assign(last_attempt_at: actor.deleted_at.not_nil! + 1.day).save }

          it "does not delete the verdict" do
            expect { subject.perform }.not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
          end

          it "does not delete the materialized row" do
            expect { subject.perform }.not_to change { materialized_count(feed) }.from(1)
          end
        end
      end
    end

    it "sets the next attempt at" do
      expect { subject.perform }.to change { subject.next_attempt_at }.from(nil)
    end
  end
end
