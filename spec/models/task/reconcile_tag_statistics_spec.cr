require "../../../src/models/task/reconcile_tag_statistics"
require "../../../src/models/tag"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::ReconcileTagStatistics do
  setup_spec

  let_create!(:object, published: Time.local)
  let_create!(:tag, subject_iri: object.iri, name: "foobar")

  describe "#perform" do
    context "with a drifted count" do
      before_each { object.attributed_to.block! }

      it "reconciles the statistics" do
        expect { subject.perform }.to change { Tag.match("foobar") }.from([{"foobar", 1}]).to([{"foobar", 0}])
      end
    end

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).to be_within(1.minute).of(15.minutes.from_now)
    end
  end
end
