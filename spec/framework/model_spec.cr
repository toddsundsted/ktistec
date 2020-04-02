require "../spec_helper"

class FooBarModel
  include Balloon::Model

  @[Persistent]
  property foo : String?

  @[Persistent]
  property bar : String?
end

class NotNilModel
  include Balloon::Model

  @[Persistent]
  property key : String = "Key"

  @[Persistent]
  property val : String
end

Spectator.describe Balloon::Model::Utils do
  describe "#table_name" do
    it "returns the table name" do
      expect(described_class.table_name(SemanticVersion)).to eq("semantic_versions")
      expect(described_class.table_name(Process)).to eq("processes")
    end
  end
end

Spectator.describe Balloon::Model do
  before_each do
    Balloon.database.exec "CREATE TABLE foo_bar_models (id integer PRIMARY KEY AUTOINCREMENT, foo text, bar text)"
    Balloon.database.exec "CREATE TABLE not_nil_models (id integer PRIMARY KEY AUTOINCREMENT, key text NOT NULL, val text NOT NULL)"
  end
  after_each do
    Balloon.database.exec "DROP TABLE foo_bar_models"
    Balloon.database.exec "DROP TABLE not_nil_models"
  end
end
