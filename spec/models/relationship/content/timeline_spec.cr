require "../../../../src/models/relationship/content/timeline"
# ensure all subtypes are compiled in and the guard below sees them
require "../../../../src/models/relationship/content/timeline/**" # ameba:disable Ktistec/NoRequireGlob

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Content::Timeline do
  setup_spec

  alias Timeline = Relationship::Content::Timeline::Create

  let_create(:actor, named: from)
  let_create(:object, named: to)

  let(options) do
    {
      from_iri: from.iri,
      to_iri:   to.iri,
    }
  end

  describe ".type_in_list" do
    # the partial index `idx_relationships_timeline_from_iri_created_at`
    # binds only when the read query interpolates exactly this list, in
    # this order. if a subtype is added, removed, or renamed this fails,
    # signalling that the index migration's predicate must be updated to
    # match (see `20260615162507-add-timeline-index.cr`).
    it "matches the partial index predicate byte-for-byte" do
      expect(described_class.type_in_list).to eq(
        "'Relationship::Content::Timeline::Announce','Relationship::Content::Timeline::Create'",
      )
    end
  end

  context "creation" do
    let(relationship) { Timeline.new(**options).save }

    it "creates confirmed relationships by default" do
      expect(relationship.confirmed).to be_true
    end
  end

  context "validation" do
    it "rejects missing owner" do
      new_relationship = Timeline.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("owner")
    end

    it "rejects missing object" do
      new_relationship = Timeline.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("object")
    end

    it "successfully validates instance" do
      new_relationship = Timeline.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
