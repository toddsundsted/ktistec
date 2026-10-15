require "../../../../src/models/task/feed/collect_drafts"
require "../../../../src/services/feed/backend/criteria"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Task::Feed::CollectDrafts do
  setup_spec

  def materialized_count(feed)
    Ktistec.database.scalar(
      "SELECT count(*) FROM relationships WHERE from_iri = ? AND type = ?",
      feed.owner_iri, feed.feed_type,
    ).as(Int64)
  end

  def back_date(feed, hours)
    Ktistec.database.exec(
      "UPDATE feeds SET updated_at = datetime('now', ?) WHERE id = ?",
      "-#{hours} hours", feed.id,
    )
  end

  describe "#perform" do
    let_create!(:feed, named: draft, draft: true)

    context "given a draft past the maximum age" do
      before_each { back_date(draft, 169) }

      it "destroys the draft" do
        expect { subject.perform }.to change { Feed.count(id: draft.id) }.from(1).to(0)
      end

      it "returns the number of drafts destroyed" do
        expect(subject.perform).to eq(1)
      end

      context "that is registered" do
        around_each do |proc|
          saved = Rules::View.registry.dup
          begin
            proc.call
          ensure
            Rules::View.registry.clear
            Rules::View.registry.concat(saved)
          end
        end

        before_each { Rules::Feeds.register(draft) }

        it "unregisters the draft's view" do
          subject.perform
          expect(Rules::View.registry.map(&.type)).not_to contain(draft.feed_type)
        end
      end

      context "with contents" do
        let_build(:object)

        before_each { put_in_feed(draft, object) }

        pre_condition { expect(materialized_count(draft)).to eq(1) }

        it "deletes the draft's materialized rows" do
          expect { subject.perform }.to change { materialized_count(draft) }.from(1).to(0)
        end
      end
    end

    context "given a draft within the maximum age" do
      before_each { back_date(draft, 167) }

      it "does not destroy the draft" do
        expect { subject.perform }.not_to change { Feed.count(id: draft.id) }.from(1)
      end
    end

    context "given a published feed past the maximum age" do
      let_create!(:feed, named: published, draft: false)

      before_each { back_date(published, 169) }

      it "does not destroy the feed" do
        expect { subject.perform }.not_to change { Feed.count(id: published.id) }.from(1)
      end
    end

    it "sets the next attempt at" do
      expect { subject.perform }.to change { subject.next_attempt_at }.from(nil)
    end

    # a raising `perform` must not leave the singleton permanently
    # unscheduled. an out-of-range age is the cheapest way to raise
    # (computing the cutoff overflows).
    it "sets the next attempt at" do
      expect { subject.perform(max_age_hours: Int32::MAX) }.to raise_error(ArgumentError)
      expect(subject.next_attempt_at).not_to be_nil
    end
  end
end
