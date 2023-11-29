require "../../../src/framework/model/deletable"

require "../../spec_helper/base"

class DeletableModel
  include Ktistec::Model(Deletable)

  validates(deleted_at) { "must not be deleted" if deleted_at }
end

Spectator.describe Ktistec::Model::Deletable do
  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE deletable_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        deleted_at datetime
      )
    SQL
  end
  after_each do
    Ktistec.database.exec "DROP TABLE deletable_models"
  end

  describe ".new" do
    it "includes Ktistec::Model::Deletable" do
      expect(DeletableModel.new).to be_a(Ktistec::Model::Deletable)
    end
  end

  describe "#delete!" do
    let!(deletable) { DeletableModel.new.save }

    it "deletes the instance" do
      expect{deletable.delete!}.to change{DeletableModel.count}.by(-1)
    end

    it "sets deleted_at" do
      expect{deletable.delete!}.to change{deletable.deleted_at}
    end
  end

  context "a deleted record" do
    before_each do
      Ktistec.database.exec("INSERT INTO deletable_models (id, deleted_at) VALUES (?, ?)", 9999, Time.utc)
    end

    it "isn't counted" do
      expect(DeletableModel.count).to eq(0)
    end

    it "isn't counted unless explicitly included" do
      expect(DeletableModel.count(include_deleted: true)).to eq(1)
    end

    it "isn't counted" do
      expect(DeletableModel.count(id: 9999)).to eq(0)
    end

    it "isn't counted unless explicitly included" do
      expect(DeletableModel.count(id: 9999, include_deleted: true)).to eq(1)
    end

    it "isn't returned" do
      expect(DeletableModel.all).to be_empty
    end

    it "isn't returned unless explicitly included" do
      expect(DeletableModel.all(include_deleted: true)).not_to be_empty
    end

    it "can't be found" do
      expect(DeletableModel.find?(9999)).to be_nil
    end

    it "can't be found unless explicitly included" do
      expect(DeletableModel.find?(9999, include_deleted: true)).not_to be_nil
    end

    it "can't be found" do
      expect(DeletableModel.find?(id: 9999)).to be_nil
    end

    it "can't be found unless explicitly included" do
      expect(DeletableModel.find?(id: 9999, include_deleted: true)).not_to be_nil
    end

    it "can't be found" do
      expect(DeletableModel.where(id: 9999)).to be_empty
    end

    it "can't be found unless explicitly included" do
      expect(DeletableModel.where(id: 9999, include_deleted: true)).not_to be_empty
    end

    it "can't be found" do
      expect(DeletableModel.where("id = ?", 9999)).to be_empty
    end

    it "can't be found unless explicitly included" do
      expect(DeletableModel.where("id = ?", 9999, include_deleted: true)).not_to be_empty
    end
  end

  context "a deleted instance" do
    let(deletable) { DeletableModel.new(deleted_at: Time.utc) }

    it "won't be validated" do
      expect(deletable.valid?).to be_true
    end

    it "won't be saved" do
      expect{deletable.save}.not_to change{deletable.id}
    end
  end
end
