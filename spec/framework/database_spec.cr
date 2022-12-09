require "../../src/framework/database"

require "../spec_helper/base"

class TestMigraton
  extend Ktistec::Database::Migration

  def initialize(name)
    up(name) {}
    down(name) {}
  end
end

Spectator.describe Ktistec::Database do
  setup_spec

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

Spectator.describe Ktistec::Database::Migration do
  setup_spec

  subject { TestMigraton }

  before_each do
    Ktistec.database.exec <<-STR
    CREATE TABLE foobars (
    id integer PRIMARY KEY AUTOINCREMENT,
    name varchar(244) NOT NULL DEFAULT "",
    value integer
    )
    STR
    Ktistec.database.exec <<-STR
    CREATE UNIQUE INDEX idx_foobars_name
    ON foobars (name ASC)
    STR
    Ktistec.database.exec %q|INSERT INTO foobars VALUES (1, "one", 1)|
    Ktistec.database.exec %q|INSERT INTO foobars VALUES (2, "two", 2)|
  end

  describe ".columns" do
    it "returns the table's columns" do
      expect(subject.columns("foobars")).to contain_exactly(%q|id integer PRIMARY KEY AUTOINCREMENT|, %q|name varchar(244) NOT NULL DEFAULT ""|, %q|value integer|)
    end
  end

  describe ".indexes" do
    it "returns the table's indexes" do
      expect(subject.indexes("foobars")).to contain_exactly(%Q|CREATE UNIQUE INDEX idx_foobars_name\nON foobars (name ASC)|)
    end
  end

  describe ".add_column" do
    it "adds the column" do
      expect{subject.add_column("foobars", "other", "text")}.to change{subject.columns("foobars")}.to([%q|id integer PRIMARY KEY AUTOINCREMENT|, %q|name varchar(244) NOT NULL DEFAULT ""|, %q|value integer|, %q|other text|])
    end
  end

  describe ".remove_column" do
    it "removes the column" do
      expect{subject.remove_column("foobars", "value")}.to change{subject.columns("foobars")}.to([%q|id integer PRIMARY KEY AUTOINCREMENT|, %q|name varchar(244) NOT NULL DEFAULT ""|])
    end

    it "retains the data" do
      expect{subject.remove_column("foobars", "value")}.not_to change{Ktistec.database.scalar("SELECT count(*) FROM foobars")}
    end

    it "retains the indexes" do
      expect{subject.remove_column("foobars", "value")}.not_to change{subject.indexes("foobars")}
    end
  end
end
