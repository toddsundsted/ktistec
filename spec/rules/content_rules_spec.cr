require "../../src/rules/content_rules"

require "../spec_helper/factory"
require "../spec_helper/model"

Spectator.describe ContentRules do
  setup_spec

  let_build(:actor)
  let_build(:activity)

  describe ".new" do
    it "creates an instance for a given actor and activity" do
      expect(described_class.new(actor, activity)).to be_a(ContentRules)
    end
  end

  describe "#run" do
    subject { described_class.new(actor, activity) }

    it "runs the rules engine" do
      expect{subject.run}.not_to raise_error
    end
  end
end
