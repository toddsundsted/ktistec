require "../spec_helper"

Spectator.describe Balloon::JSON_LD do
  describe "::CONTEXTS" do
    it "loads stored contexts" do
      expect(Balloon::JSON_LD::CONTEXTS).not_to be_empty
    end
  end
end
