require "../../spec_helper"

class PolymorphicModel
  include Balloon::Model(Polymorphic)

  @@table_name = "polymorphic_models"
end

class Subclass1 < PolymorphicModel
end

class Subclass2 < PolymorphicModel
end

Spectator.describe Balloon::Model::Polymorphic do
  before_each do
    Balloon.database.exec <<-SQL
      CREATE TABLE polymorphic_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        type varchar(32) NOT NULL
      )
    SQL
  end
  after_each do
    Balloon.database.exec "DROP TABLE polymorphic_models"
  end

  describe ".new" do
    it "includes Balloon::Model::Polymorphic" do
      expect(PolymorphicModel.new).to be_a(Balloon::Model::Polymorphic)
    end
  end

  let!(subclass1) { Subclass1.new.save }
  let!(subclass2) { Subclass2.new.save }

  describe ".find" do
    it "finds the instance" do
      expect(Subclass1.find(subclass1.id)).to be_a(Subclass1)
      expect(Subclass1.find(id: subclass1.id)).to be_a(Subclass1)
    end

    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id, as: Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id, as: Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect{Subclass1.find(subclass2.id)}.to raise_error(Balloon::Model::NotFound)
      expect{Subclass1.find(id: subclass2.id)}.to raise_error(Balloon::Model::NotFound)
    end

    it "raises an error" do
      expect{PolymorphicModel.find(subclass2.id, as: Subclass1)}.to raise_error(Balloon::Model::NotFound)
      expect{PolymorphicModel.find(id: subclass2.id, as: Subclass1)}.to raise_error(Balloon::Model::NotFound)
    end
  end

  describe "#as_a" do
    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect{PolymorphicModel.find(subclass2.id).as_a(Subclass1)}.to raise_error(Balloon::Model::NotFound)
      expect{PolymorphicModel.find(id: subclass2.id).as_a(Subclass1)}.to raise_error(Balloon::Model::NotFound)
    end
  end
end
