require "../../../../src/models/activity_pub/mixins/blockable"

require "../../../spec_helper/base"

class BlockableModel
  include Ktistec::Model
  include Ktistec::Model::Blockable
end

Spectator.describe Ktistec::Model::Blockable do
  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE IF NOT EXISTS blockable_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        blocked_at datetime
      )
    SQL
  end
  after_each do
    Ktistec.database.exec "DROP TABLE IF EXISTS blockable_models"
  end

  describe ".new" do
    it "includes Ktistec::Model::Blockable" do
      expect(BlockableModel.new).to be_a(Ktistec::Model::Blockable)
    end
  end

  describe "#block!" do
    let!(blockable) { BlockableModel.new.save }

    pre_condition { expect(blockable.blocked?).to be_false }

    it "blocks the instance" do
      expect { blockable.block! }.to change { blockable.blocked? }
    end

    it "sets blocked_at" do
      expect { blockable.block! }.to change { blockable.reload!.blocked_at }
    end
  end

  describe "#unblock!" do
    let!(blockable) { BlockableModel.new(blocked_at: Time.utc).save }

    pre_condition { expect(blockable.blocked?).to be_true }

    it "unblocks the instance" do
      expect { blockable.unblock! }.to change { blockable.blocked? }
    end

    it "clears blocked_at" do
      expect { blockable.unblock! }.to change { blockable.reload!.blocked_at }
    end
  end
end
