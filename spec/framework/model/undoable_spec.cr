require "../../../src/framework/model/undoable"

require "../../spec_helper/base"

class UndoableModel
  include Ktistec::Model(Undoable)

  validates(undone_at) { "must not be undone" if undone_at }
end

Spectator.describe Ktistec::Model::Undoable do
  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE undoable_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        undone_at datetime
      )
    SQL
  end
  after_each do
    Ktistec.database.exec "DROP TABLE undoable_models"
  end

  describe ".new" do
    it "includes Ktistec::Model::Undoable" do
      expect(UndoableModel.new).to be_a(Ktistec::Model::Undoable)
    end
  end

  describe "#undo" do
    let!(undoable) { UndoableModel.new.save }

    it "undoes the instance" do
      expect{undoable.undo}.to change{UndoableModel.count}.by(-1)
    end

    it "sets undone_at" do
      expect{undoable.undo}.to change{undoable.undone_at}
    end
  end

  context "an undone record" do
    before_each do
      Ktistec.database.exec("INSERT INTO undoable_models (id, undone_at) VALUES (?, ?)", 9999, Time.utc)
    end

    it "isn't counted" do
      expect(UndoableModel.count).to eq(0)
    end

    it "isn't counted unless explicitly included" do
      expect(UndoableModel.count(include_undone: true)).to eq(1)
    end

    it "isn't counted" do
      expect(UndoableModel.count(id: 9999)).to eq(0)
    end

    it "isn't counted unless explicitly included" do
      expect(UndoableModel.count(id: 9999, include_undone: true)).to eq(1)
    end

    it "isn't returned" do
      expect(UndoableModel.all).to be_empty
    end

    it "isn't returned unless explicitly included" do
      expect(UndoableModel.all(include_undone: true)).not_to be_empty
    end

    it "can't be found" do
      expect(UndoableModel.find?(9999)).to be_nil
    end

    it "can't be found unless explicitly included" do
      expect(UndoableModel.find?(9999, include_undone: true)).not_to be_nil
    end

    it "can't be found" do
      expect(UndoableModel.find?(id: 9999)).to be_nil
    end

    it "can't be found unless explicitly included" do
      expect(UndoableModel.find?(id: 9999, include_undone: true)).not_to be_nil
    end

    it "can't be found" do
      expect(UndoableModel.where(id: 9999)).to be_empty
    end

    it "can't be found unless explicitly included" do
      expect(UndoableModel.where(id: 9999, include_undone: true)).not_to be_empty
    end

    it "can't be found" do
      expect(UndoableModel.where("id = ?", 9999)).to be_empty
    end

    it "can't be found unless explicitly included" do
      expect(UndoableModel.where("id = ?", 9999, include_undone: true)).not_to be_empty
    end
  end

  context "an undone instance" do
    let(undoable) { UndoableModel.new(undone_at: Time.utc) }

    it "won't be validated" do
      expect(undoable.valid?).to be_true
    end

    it "won't be saved" do
      expect{undoable.save}.not_to change{undoable.id}
    end
  end
end
