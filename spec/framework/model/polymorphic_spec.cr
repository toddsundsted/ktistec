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
    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id, as: Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(type: "Subclass1", as: Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect{PolymorphicModel.find(subclass2.id, as: Subclass1)}.to raise_error(TypeCastError)
      expect{PolymorphicModel.find(type: "Subclass2", as: Subclass1)}.to raise_error(TypeCastError)
    end
  end

  describe "#as_a" do
    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(type: "Subclass1").as_a(Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect{PolymorphicModel.find(subclass2.id).as_a(Subclass1)}.to raise_error(TypeCastError)
      expect{PolymorphicModel.find(type: "Subclass2").as_a(Subclass1)}.to raise_error(TypeCastError)
    end
  end
end
