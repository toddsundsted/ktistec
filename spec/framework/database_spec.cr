require "../spec_helper"

class TestMigraton
  include Balloon::Database::Migration

  def initialize(name)
    up(name) {}
    down(name) {}
  end
end

Spectator.describe Balloon::Database do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let!(test) { TestMigraton.new("999999-test-migration.cr") }

  describe ".all_migrations" do
    it "returns migrations" do
      expect(described_class.all_migrations).to_not be_empty
    end
  end

  describe ".all_versions" do
    it "returns versions" do
      expect(described_class.all_versions).to_not be_empty
    end
  end

  describe ".all_applied_versions" do
    it "does not include test migration" do
      expect(described_class.all_applied_versions).to_not have(999999)
    end
  end

  describe ".all_pending_versions" do
    it "includes test migration" do
      expect(described_class.all_pending_versions).to contain(999999)
    end
  end

  describe ".do_operation" do
    it "creates and destroys the migration" do
      expect(described_class.all_pending_versions).to have(999999)
      expect(described_class.do_operation(:create, 999999)).to match(/created/)
      expect(described_class.all_applied_versions).to have(999999)
      expect(described_class.do_operation(:destroy, 999999)).to match(/destroyed/)
      expect(described_class.all_pending_versions).to have(999999)
    end
  end

  describe ".do_operation" do
    it "applies and reverts the migration" do
      expect(described_class.all_pending_versions).to have(999999)
      expect(described_class.do_operation(:apply, 999999)).to match(/applied/)
      expect(described_class.all_applied_versions).to have(999999)
      expect(described_class.do_operation(:revert, 999999)).to match(/reverted/)
      expect(described_class.all_pending_versions).to have(999999)
    end
  end
end
