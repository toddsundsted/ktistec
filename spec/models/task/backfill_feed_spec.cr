require "../../../src/models/task/backfill_feed"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::BackfillFeed do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, draft: false, floor: Time.utc(1970, 1, 1), params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

  subject { described_class.new(source_iri: actor.iri, subject_iri: described_class.iri_for(feed)).save }

  describe ".schedule_for" do
    around_each do |proc|
      described_class.schedule_but_dont_perform = true
      proc.call
      described_class.schedule_but_dont_perform = false
    end

    it "schedules a backfill" do
      expect { described_class.schedule_for(feed) }
        .to change { described_class.count(subject_iri: described_class.iri_for(feed)) }.from(0).to(1)
    end

    context "when the feed has no floor" do
      before_each { feed.assign(floor: nil).save }

      it "does not schedule a backfill" do
        expect { described_class.schedule_for(feed) }
          .not_to change { described_class.count }.from(0)
      end
    end

    context "when the feed is a draft" do
      before_each { feed.assign(draft: true).save }

      it "does not schedule a backfill" do
        expect { described_class.schedule_for(feed) }
          .not_to change { described_class.count }.from(0)
      end
    end

    context "when a backfill is already scheduled" do
      before_each { described_class.schedule_for(feed) }

      pre_condition { expect(described_class.count).to eq(1) }

      it "does not schedule another backfill" do
        expect { described_class.schedule_for(feed) }
          .not_to change { described_class.count }.from(1)
      end
    end
  end

  describe ".destroy_for" do
    before_each { subject }

    pre_condition { expect(described_class.count(subject_iri: described_class.iri_for(feed))).to eq(1) }

    it "destroys the feed's backfill" do
      expect { described_class.destroy_for(feed) }
        .to change { described_class.count(subject_iri: described_class.iri_for(feed)) }.from(1).to(0)
    end

    context "given a backfill for another feed" do
      let_create!(:feed, named: other, owner: actor, draft: false, floor: Time.utc(1970, 1, 1))

      before_each { described_class.new(source_iri: actor.iri, subject_iri: described_class.iri_for(other)).save }

      it "does not destroy the other feed's backfill" do
        described_class.destroy_for(feed)
        expect(described_class.count(subject_iri: described_class.iri_for(other))).to eq(1)
      end
    end
  end

  describe "#feed?" do
    it "returns the feed" do
      expect(subject.feed?).to eq(feed)
    end

    context "when the feed is destroyed" do
      before_each { feed.destroy }

      it "returns nil" do
        expect(subject.feed?).to be_nil
      end
    end
  end

  describe "#perform" do
    it "does not reschedule" do
      expect { subject.perform }.not_to change { subject.next_attempt_at }
    end

    context "given posts in the owner's inbox" do
      let_build(:object, named: hit, content: "<p>something alpha something</p>")
      let_build(:object, named: miss, content: "<p>something gamma something</p>")
      let_create(:create, named: hit_create, object: hit)
      let_create(:create, named: miss_create, object: miss)
      let!(hit_row) { put_in_inbox(actor, hit_create) }
      let!(miss_row) { put_in_inbox(actor, miss_create) }

      it "reschedules" do
        expect { subject.perform(1) }.to change { subject.next_attempt_at }
      end

      it "does not reschedule once the mailbox is exhausted" do
        expect { subject.perform }.not_to change { subject.next_attempt_at }
      end

      it "records the cursor" do
        subject.perform
        expect(subject.state.cursor).to eq(hit_row.id)
      end

      it "counts what it scanned" do
        subject.perform
        expect(subject.state.scanned).to eq(2)
      end

      it "counts what it included" do
        subject.perform
        expect(subject.state.included).to eq(1)
      end

      context "when a batch judges only the newest candidate" do
        before_each do
          subject.perform(1)
          subject.save
        end

        pre_condition { expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0) }

        it "judges the next candidate when the task is reloaded" do
          described_class.find(subject.id).perform(1)
          expect(Feed::Verdict.find(feed_id: feed.id, object_iri: hit.iri).included).to be_true
        end
      end

      context "when the feed's floor is above the posts" do
        before_each { feed.assign(floor: miss_row.created_at + 1.second).save }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
        end
      end

      context "when the feed has no floor" do
        before_each { feed.assign(floor: nil).save }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
        end

        it "does not reschedule" do
          expect { subject.perform }.not_to change { subject.next_attempt_at }
        end
      end

      context "when the feed is a draft" do
        before_each { feed.assign(draft: true).save }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
        end

        it "does not reschedule" do
          expect { subject.perform }.not_to change { subject.next_attempt_at }
        end
      end

      context "when the feed is destroyed" do
        before_each { feed.destroy }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
        end

        it "does not reschedule" do
          expect { subject.perform }.not_to change { subject.next_attempt_at }
        end
      end

      context "and two more that arrived in the same millisecond" do
        let_build(:object, named: early, content: "<p>something alpha something</p>")
        let_build(:object, named: late, content: "<p>something gamma something</p>")
        let_create(:create, named: early_create, object: early)
        let_create(:create, named: late_create, object: late)

        let(instant) { Time.utc(2026, 1, 1, 1, 1, 1, nanosecond: 700_000_000) }

        let_create!(:inbox_relationship, named: nil, owner: actor, activity: early_create, created_at: instant)
        let_create!(:inbox_relationship, named: nil, owner: actor, activity: late_create, created_at: instant)

        it "judges the second of them when the task is reloaded" do
          subject.perform(1)
          subject.save
          described_class.find(subject.id).perform(1)
          expect(Feed::Verdict.find?(feed_id: feed.id, object_iri: early.iri).try(&.included)).to be_true
        end
      end

      context "when run by the task worker" do
        before_each { TaskWorker.instance.perform(subject) }

        it "marks the task complete" do
          expect(subject.complete).to be_true
        end
      end
    end
  end
end
