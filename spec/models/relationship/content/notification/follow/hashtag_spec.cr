require "../../../../../../src/models/relationship/content/notification/follow/hashtag"

require "../../../../../spec_helper/base"
require "../../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Notification::Follow::Hashtag do
  setup_spec

  let_create(:actor, named: owner)

  let(options) do
    {
      owner: owner,
      name:  "hashtag",
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
