require "../spec_helper"

Spectator.describe Balloon::Model::Utils do
  describe "#table_name" do
    it "returns the table name" do
      expect(described_class.table_name(SemanticVersion)).to eq("semantic_versions")
      expect(described_class.table_name(Process)).to eq("processes")
    end
  end
end
