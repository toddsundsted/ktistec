require "../../../src/framework/model/polymorphic"

require "../../spec_helper/base"

class PolymorphicModel
  include Ktistec::Model
  include Ktistec::Model::Polymorphic

  @@table_name = "polymorphic_models"

  @@table_columns = [
    "state",
    "stamp",
  ]

  ALIASES = [
    "Alias",
  ]
end

class Subclass1 < PolymorphicModel
end

class Subclass2 < PolymorphicModel
end

class Subclass3 < PolymorphicModel
  class State
    include JSON::Serializable

    property id : Int64?

    def_equals_and_hash(id)

    def initialize(@id = nil)
    end
  end

  @[Persistent]
  @[Insignificant]
  property state : State { State.new }
end

class Subclass4 < PolymorphicModel
  class State
    include JSON::Serializable

    property str : String?

    def_equals_and_hash(str)

    def initialize(@str = nil)
    end
  end

  @[Persistent]
  @[Insignificant]
  property state : State { State.new }
end

class Subclass5 < PolymorphicModel
  @[Persistent]
  @[Insignificant]
  property stamp : Time { Time.utc }
end

abstract class Subclass6 < PolymorphicModel
end

Spectator.describe Ktistec::Model::Polymorphic do
  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE IF NOT EXISTS polymorphic_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        type varchar(32) NOT NULL,
        state text,
        stamp datetime
      )
    SQL
  end
  after_each do
    Ktistec.database.exec <<-SQL
      DROP TABLE IF EXISTS polymorphic_models
    SQL
  end

  describe ".new" do
    it "includes Ktistec::Model::Polymorphic" do
      expect(PolymorphicModel.new).to be_a(Ktistec::Model::Polymorphic)
    end
  end

  let(state3) { Subclass3::State.new(9999_i64) }
  let(state4) { Subclass4::State.new("test") }
  let(stamp) { 5.days.ago.to_utc }
  let!(subclass1) { Subclass1.new.save }
  let!(subclass2) { Subclass2.new.save }
  let!(subclass3) { Subclass3.new(state: state3).save }
  let!(subclass4) { Subclass4.new(state: state4).save }
  let!(subclass5) { Subclass5.new(stamp: stamp).save }

  describe ".count" do
    it "returns the count" do
      expect(PolymorphicModel.count).to eq(5)
      expect(PolymorphicModel.count(id: subclass2.id)).to eq(1)
    end

    it "returns the count for subclass" do
      expect(Subclass1.count).to eq(1)
      expect(Subclass1.count(id: subclass2.id)).to eq(0)
    end
  end

  describe ".all" do
    it "finds all instances" do
      expect(PolymorphicModel.all).to eq([subclass1, subclass2, subclass3, subclass4, subclass5])
    end

    it "finds all instances of subclass" do
      expect(Subclass1.all).to eq([subclass1])
    end
  end

  describe ".where" do
    it "finds all matching instances" do
      expect(PolymorphicModel.where(id: subclass2.id)).to eq([subclass2])
      expect(PolymorphicModel.where("id = ?", subclass2.id)).to eq([subclass2])
    end

    it "does not find any matching instances of subclass" do
      expect(Subclass1.where(id: subclass2.id)).to be_empty
      expect(Subclass1.where("id = ?", subclass2.id)).to be_empty
    end
  end

  describe ".find" do
    it "finds the matching instance" do
      expect(PolymorphicModel.find(subclass1.id)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id)).to be_a(Subclass1)
    end

    it "finds the matching instance of subclass" do
      expect(Subclass1.find(subclass1.id)).to be_a(Subclass1)
      expect(Subclass1.find(id: subclass1.id)).to be_a(Subclass1)
    end

    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id, as: Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id, as: Subclass1)).to be_a(Subclass1)
    end

    it "populates the uninherited properties of subclass" do
      expect(PolymorphicModel.find(subclass3.id).as(Subclass3).state).to eq(state3)
      expect(PolymorphicModel.find(id: subclass3.id).as(Subclass3).state).to eq(state3)
    end

    it "populates the uninherited properties of subclass" do
      expect(PolymorphicModel.find(subclass4.id).as(Subclass4).state).to eq(state4)
      expect(PolymorphicModel.find(id: subclass4.id).as(Subclass4).state).to eq(state4)
    end

    it "populates the uninherited properties of subclass" do
      expect(PolymorphicModel.find(subclass5.id).as(Subclass5).stamp).to be_within(1.second).of(stamp)
      expect(PolymorphicModel.find(id: subclass5.id).as(Subclass5).stamp).to be_within(1.second).of(stamp)
    end

    it "raises an error" do
      expect { Subclass1.find(subclass2.id) }.to raise_error(Ktistec::Model::NotFound)
      expect { Subclass1.find(id: subclass2.id) }.to raise_error(Ktistec::Model::NotFound)
    end

    it "raises an error" do
      expect { PolymorphicModel.find(subclass2.id, as: Subclass1) }.to raise_error(Ktistec::Model::NotFound)
      expect { PolymorphicModel.find(id: subclass2.id, as: Subclass1) }.to raise_error(Ktistec::Model::NotFound)
    end

    context "when instantiating an abstract model" do
      before_each do
        Ktistec.database.exec <<-SQL
          INSERT INTO polymorphic_models (id, type) VALUES (9999, 'Subclass6')
        SQL
      end

      it "raises an error" do
        expect { PolymorphicModel.find(9999_i64) }
          .to raise_error(Ktistec::Model::TypeError, /cannot instantiate abstract model/)
      end

      it "raises an error" do
        expect { Subclass6.find(9999_i64) }
          .to raise_error(Ktistec::Model::TypeError, /cannot instantiate abstract model/)
      end
    end
  end

  describe ".all_subtypes" do
    it "includes the alias" do
      expect(PolymorphicModel.all_subtypes).to have("Alias")
    end
  end

  describe "#as_a" do
    it "returns the correct subclass" do
      expect(PolymorphicModel.find(subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
      expect(PolymorphicModel.find(id: subclass1.id).as_a(Subclass1)).to be_a(Subclass1)
    end

    it "raises an error" do
      expect { PolymorphicModel.find(subclass2.id).as_a(Subclass1) }.to raise_error(Ktistec::Model::NotFound)
      expect { PolymorphicModel.find(id: subclass2.id).as_a(Subclass1) }.to raise_error(Ktistec::Model::NotFound)
    end
  end

  describe "#valid?" do
    it "returns false if the type is invalid" do
      expect(PolymorphicModel.new(type: "SubclassXYZ").valid?).to be_false
    end
  end
end
