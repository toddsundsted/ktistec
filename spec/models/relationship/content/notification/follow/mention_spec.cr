require "../../../../../../src/models/relationship/content/notification/follow/mention"

require "../../../../../spec_helper/base"
require "../../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Notification::Follow::Mention do
  setup_spec

  let(options) do
    {
      owner: Factory.create(:actor),
      name: "foo@bar"
    }
  end

  context "validation" do
    it "rejects blank name" do
      new_relationship = described_class.new(**options.merge({name: ""}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("name")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
