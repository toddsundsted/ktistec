require "../../../src/framework/model/polymorphic"

require "../../spec_helper/base"

class PolymorphicModel
  include Ktistec::Model(Polymorphic)

  @@table_name = "polymorphic_models"
end

class Subclass1 < PolymorphicModel
end

class Subclass2 < PolymorphicModel
end

Spectator.describe Ktistec::Model::Polymorphic do
  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE polymorphic_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        type varchar(32) NOT NULL
      )
    SQL
  end
  after_each do
    Ktistec.database.exec <<-SQL
      DROP TABLE polymorphic_models
    SQL
  end

  describe ".new" do
    it "includes Ktistec::Model::Polymorphic" do
      expect(PolymorphicModel.new).to be_a(Ktistec::Model::Polymorphic)
    end
  end

  let!(subclass1) { Subclass1.new.save }
  let!(subclass2) { Subclass2.new.save }

  describe ".count" do
    it "returns the count" do
      expect(PolymorphicModel.count).to eq(2)
      expect(PolymorphicModel.count(id: subclass2.id)).to eq(1)
    end

    it "returns the count for subclass" do
      expect(Subclass1.count).to eq(1)
      expect(Subclass1.count(id: subclass2.id)).to eq(0)
    end
  end

  describe ".all" do
    it "finds all instances" do
      expect(PolymorphicModel.all).to eq([subclass1, subclass2])
    end

    it "finds all instances of subclass" do
      expect(Subclass1.all).to eq([subclass1])
    end
  end

  describe ".where" do
    it "finds all instances" do
      expect(PolymorphicModel.where(id: subclass2.id)).to eq([subclass2])
      expect(PolymorphicModel.where("id = ?", subclass2.id)).to eq([subclass2])
    end

    it "finds all instances of subclass" do
      expect(Subclass1.where(id: subclass2.id)).to be_empty
      expect(Subclass1.where("id = ?", subclass2.id)).to be_empty
    end
  end

  describe ".find" do
    it "finds the instance" do
      expect(PolymorphicModel.find(subclass1.id)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id)).to be_a(Subclass1)
    end

    it "finds the instance of subclass" do
      expect(Subclass1.find(subclass1.id)).to be_a(Subclass1)
      expect(Subclass1.find(id: subclass1.id)).to be_a(Subclass1)
    end

    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id, as: Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id, as: Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect{Subclass1.find(subclass2.id)}.to raise_error(Ktistec::Model::NotFound)
      expect{Subclass1.find(id: subclass2.id)}.to raise_error(Ktistec::Model::NotFound)
    end

    it "raises an error" do
      expect{PolymorphicModel.find(subclass2.id, as: Subclass1)}.to raise_error(Ktistec::Model::NotFound)
      expect{PolymorphicModel.find(id: subclass2.id, as: Subclass1)}.to raise_error(Ktistec::Model::NotFound)
    end
  end

  describe "#as_a" do
    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect{PolymorphicModel.find(subclass2.id).as_a(Subclass1)}.to raise_error(Ktistec::Model::NotFound)
      expect{PolymorphicModel.find(id: subclass2.id).as_a(Subclass1)}.to raise_error(Ktistec::Model::NotFound)
    end
  end
end
