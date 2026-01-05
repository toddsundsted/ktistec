require "../../../../src/models/relationship/content/notification"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Content::Notification do
  setup_spec

  class Notification < Relationship::Content::Notification
    # a non-abstract version to test
  end

  let_create(:actor, named: from)

  let(options) do
    {
      from_iri: from.iri,
      to_iri: "anything",
    }
  end

  context "creation" do
    let(relationship) { Notification.new(**options).save }

    it "creates confirmed relationships by default" do
      expect(relationship.confirmed).to be_true
    end
  end

  context "validation" do
    it "rejects missing owner" do
      new_relationship = Notification.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("owner")
    end

    it "successfully validates instance" do
      new_relationship = Notification.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
