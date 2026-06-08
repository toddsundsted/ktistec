require "../../../../../../src/models/relationship/content/notification/follow/mention"

require "../../../../../spec_helper/base"
require "../../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Notification::Follow::Mention do
  setup_spec

  let_create(:actor, named: owner)

  let(options) do
    {
      owner: owner,
      href:  "https://bar/actors/foo",
    }
  end

  context "validation" do
    it "rejects blank href" do
      new_relationship = described_class.new(**options.merge({href: ""}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("href")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
