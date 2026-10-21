require "../../../src/services/feed/revisions"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Revisions do
  setup_spec

  describe ".update" do
    context "given a published feed whose backend reports a new revision" do
      let_create!(:feed, draft: false)

      before_each { feed.version.assign(revision: "0").save }

      it "moves the feed to a new version" do
        expect { described_class.update }.to change { Feed.find(feed.id).version_id }
      end

      it "backfills the feed" do
        described_class.update
        expect(Task::Feed::EnqueueBackfill.count(feed_id: feed.id.to_s)).to eq(1)
      end
    end

    context "given a draft feed whose backend reports a new revision" do
      let_create!(:feed, draft: true)

      before_each { feed.version.assign(revision: "0").save }

      it "moves the feed to a new version" do
        expect { described_class.update }.to change { Feed.find(feed.id).version_id }
      end

      it "does not backfill the draft" do
        described_class.update
        expect(Task::Feed::EnqueueBackfill.count(feed_id: feed.id.to_s)).to eq(0)
      end
    end
  end
end
