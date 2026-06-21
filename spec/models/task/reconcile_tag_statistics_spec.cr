require "../../../src/models/task/reconcile_tag_statistics"
require "../../../src/models/tag/hashtag"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::ReconcileTagStatistics do
  setup_spec

  let_create!(:object, published: Time.local)
  # a hashtag stands in for any reconciled type; a `Tag` alone is not sufficient
  let_create!(:hashtag, subject_iri: object.iri, name: "foobar")

  describe "#perform" do
    context "with a drifted count" do
      before_each { object.attributed_to.block! }

      it "reconciles the statistics" do
        expect { subject.perform }.to change { Tag::Hashtag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).to be_within(10.minutes).of(12.hours.from_now)
    end
  end
end
