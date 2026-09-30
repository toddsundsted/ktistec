require "../../../src/models/task/backfill_feed"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::BackfillFeed do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, draft: false, floor: Time.utc(1970, 1, 1), params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

  subject { described_class.new(source_iri: actor.iri, subject_iri: described_class.iri_for(feed)).save }

  describe ".iri_for" do
    pre_condition { expect(feed.slug).not_to be_nil }

    it "addresses the feed by id" do
      expect(described_class.iri_for(feed)).to eq("#{Ktistec.host}/actors/#{actor.username}/feeds/#{feed.id}")
    end
  end

  describe ".schedule_for" do
    around_each do |proc|
      previous = described_class.schedule_but_dont_perform
      described_class.schedule_but_dont_perform = true
      begin
        proc.call
      ensure
        described_class.schedule_but_dont_perform = previous
      end
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

    context "given objects" do
      let_create!(:object, named: hit, content: "<p>something alpha something</p>")
      let_create!(:object, named: miss, content: "<p>something gamma something</p>")

      it "reschedules" do
        expect { subject.perform(1) }.to change { subject.next_attempt_at }
      end

      it "does not reschedule once the window is exhausted" do
        expect { subject.perform }.not_to change { subject.next_attempt_at }
      end

      it "records the cursor" do
        subject.perform
        expect(subject.state.cursor).to eq(hit.id)
      end

      it "counts what it scanned" do
        subject.perform
        expect(subject.state.scanned).to eq(2)
      end

      it "counts what it included" do
        subject.perform
        expect(subject.state.included).to eq(1)
      end

      context "when the feed's floor is above every object" do
        before_each { feed.assign(floor: miss.created_at + 1.second).save }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(version_id: feed.version_id)).to eq(0)
        end

        it "records the floor id" do
          subject.perform
          expect(subject.state.floor_id).to eq(miss.id)
        end
      end

      context "when the feed's floor is below every object" do
        before_each { feed.assign(floor: Time.utc(1970, 1, 1)).save }

        it "records a zero floor id" do
          subject.perform
          expect(subject.state.floor_id).to eq(0)
        end
      end

      context "when the feed has no floor" do
        before_each { feed.assign(floor: nil).save }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(version_id: feed.version_id)).to eq(0)
        end

        it "does not reschedule" do
          expect { subject.perform }.not_to change { subject.next_attempt_at }
        end
      end

      context "when the feed is a draft" do
        before_each { feed.assign(draft: true).save }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(version_id: feed.version_id)).to eq(0)
        end

        it "does not reschedule" do
          expect { subject.perform }.not_to change { subject.next_attempt_at }
        end
      end

      context "when the feed is destroyed" do
        before_each { feed.destroy }

        it "writes no verdict" do
          subject.perform
          expect(Feed::Verdict.count(version_id: feed.version_id)).to eq(0)
        end

        it "does not reschedule" do
          expect { subject.perform }.not_to change { subject.next_attempt_at }
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
