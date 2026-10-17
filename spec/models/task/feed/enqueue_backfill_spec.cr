require "../../../../src/models/task/feed/enqueue_backfill"
require "../../../../src/services/feed/backend/criteria"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Task::Feed::EnqueueBackfill do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, draft: false, floor: Time.utc(1970, 1, 1))

  subject { described_class.new(owner: actor, feed_id: feed.id.to_s).save }

  def questions
    Feed::Question.where(version_id: feed.version_id)
  end

  describe "#perform" do
    let_create!(:object, named: candidate)

    it "enqueues the feed's candidates" do
      subject.perform
      expect(questions.map(&.object_iri)).to eq([candidate.iri])
    end

    context "when a backfill backfills every candidate" do
      before_each { Feed::Version.find(feed.version_id.not_nil!).assign(backfill_cursor: candidate.id).save }

      it "completes" do
        subject.schedule
        expect(subject.complete).to be_true
      end
    end

    context "given more candidates than fit in a page" do
      let_create!(:object, named: nil)

      pre_condition { expect(Feed::Queue.page_size).to eq(1) }

      it "enqueues no more than a page" do
        subject.perform
        expect(questions.size).to be <= Feed::Queue.page_size
      end

      it "remains scheduled" do
        subject.schedule
        expect(subject.complete).to be_false
      end
    end

    context "when the feed is destroyed" do
      before_each { feed.destroy }

      it "enqueues nothing" do
        subject.perform
        expect(questions).to be_empty
      end
    end
  end
end
