require "../../../src/rules/maintainer"
require "../../../src/rules/view/timeline_announce"
require "../../../src/rules/view/timeline_create"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe "timeline views" do
  setup_spec

  # An object that is both create-kept (the owner's own post) and
  # announced into the owner's mailbox could materialize a row in each
  # timeline view. The views are mutually exclusive by construction --
  # the create row wins -- so there is at most one timeline row per
  # `(from_iri, to_iri)`. The read query relies on this invariant; a
  # regression here would double-show the post.
  #
  describe "mutual exclusivity" do
    let(owner) { register.actor }
    let_build(:actor, named: announcer)
    let_create(:object, attributed_to: owner)
    let_create(:create, named: create_activity, actor: owner, object: object)
    let_create!(:outbox_relationship, named: nil, owner: owner, activity: create_activity)
    let_create(:announce, named: announce_activity, actor: announcer, object: object)
    let_create!(:inbox_relationship, named: nil, owner: owner, activity: announce_activity)

    it "materializes at most one timeline row per object" do
      Rules::Maintainer.reconcile_object(object.iri)
      types = Ktistec.database.query_all(
        "SELECT type FROM relationships WHERE from_iri = ? AND to_iri = ? AND type IN (#{Relationship::Content::Timeline.type_in_list})",
        owner.iri, object.iri, as: String)
      expect(types).to eq([Relationship::Content::Timeline::Create.to_s])
    end
  end
end
