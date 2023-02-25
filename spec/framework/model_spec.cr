require "json"
require "yaml"

require "../../src/framework/model"

require "../spec_helper/base"

class FooBarModel
  include Ktistec::Model(Deletable, Undoable)

  @[Persistent]
  property foo : String? = "Foo"
  validates foo do
    # no op
  end

  @[Persistent]
  property bar : String?
  validates bar do
    # no op
  end

  def validate_model
    errors["instance"] = ["foo or bar is quux"] if [foo, bar].compact.any? { |a| a.downcase == "quux" }
  end

  @[Persistent]
  property not_nil_model_id : Int64?

  belongs_to not_nil, class_name: NotNilModel, foreign_key: not_nil_model_id, inverse_of: foo_bar_models
  has_one not_nil_model, inverse_of: foo_bar
end

class NotNilModel
  include Ktistec::Model(Deletable, Undoable)

  @[Persistent]
  property key : String = "Key"
  validates key { "is not capitalized" unless key.starts_with?(/[A-Z]/) }

  @[Persistent]
  property val : String
  validates val { "is not capitalized" unless val.starts_with?(/[A-Z]/) }

  def validate_model
    errors["instance"] = ["key is equal to val"] if key == val
  end

  @[Persistent]
  property foo_bar_model_id : Int64?

  belongs_to foo_bar, class_name: FooBarModel, foreign_key: foo_bar_model_id, inverse_of: not_nil_model
  has_many foo_bar_models, inverse_of: not_nil
end

class DerivedModel < FooBarModel
  @@table_name = "foo_bar_models"

  derived index : Int64?, aliased_to: not_nil_model_id
end

class AnotherModel < NotNilModel
  @@table_name = "not_nil_models"

  derived index : Int64?, aliased_to: foo_bar_model_id
end

class UnionAssociationModel
  include Ktistec::Model(Nil)

  @[Assignable]
  property model_id : Int64?
  belongs_to model, class_name: FooBarModel | NotNilModel
end

class QueryModel
  include Ktistec::Model(Nil)

  @[Assignable]
  property foo : String?

  @[Assignable]
  property bar : String?

  def self.query_and_paginate(*args, **opts)
    super(*args, **opts)
  end

  def self.query_all(*args, **opts)
    super(*args, **opts)
  end

  def self.query_one(*args, **opts)
    super(*args, **opts)
  end
end

Spectator.describe Ktistec::Model do
  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE foo_bar_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        deleted_at datetime,
        undone_at datetime,
        not_nil_model_id integer,
        foo text,
        bar text
      )
    SQL
    Ktistec.database.exec <<-SQL
      CREATE TABLE not_nil_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        deleted_at datetime,
        undone_at datetime,
        foo_bar_model_id integer,
        key text NOT NULL,
        val text NOT NULL
      )
    SQL
  end
  after_each do
    Ktistec.database.exec "DROP TABLE foo_bar_models"
    Ktistec.database.exec "DROP TABLE not_nil_models"
  end

  describe ".table_name" do
    it "returns the table name" do
      expect(FooBarModel.table_name).to eq("foo_bar_models")
    end

    it "returns the table name" do
      expect(DerivedModel.table_name).to eq("foo_bar_models")
    end
  end

  describe "#table_name" do
    it "returns the table name" do
      expect(FooBarModel.new.table_name).to eq("foo_bar_models")
    end

    it "returns the table name" do
      expect(DerivedModel.new.table_name).to eq("foo_bar_models")
    end
  end

  describe ".values" do
    it "raises an error if column doesn't exist" do
      expect{QueryModel.values(xyz: 123)}.to raise_error(Ktistec::Model::ColumnError)
    end
  end

  describe ".conditions" do
    it "raises an error if column doesn't exist" do
      expect{QueryModel.conditions(xyz: 123)}.to raise_error(Ktistec::Model::ColumnError)
    end
  end

  describe ".query_and_paginate" do
    it "includes the additional columns" do
      query = %Q|SELECT 0, "foo", "bar", ?, ?|
      expect(QueryModel.query_and_paginate(query, additional_columns: {foo: String, bar: String})).to eq([QueryModel.new(id: 0_i64, foo: "foo", bar: "bar")])
    end
  end

  describe ".query_all" do
    it "includes the additional columns" do
      query = %Q|SELECT 0, "foo", "bar", ?, ?|
      expect(QueryModel.query_all(query, additional_columns: {foo: String, bar: String})).to eq([QueryModel.new(id: 0_i64, foo: "foo", bar: "bar")])
    end
  end

  describe ".query_one" do
    it "includes the additional columns" do
      query = %Q|SELECT 0, "foo", "bar", ?, ?|
      expect(QueryModel.query_one(query, additional_columns: {foo: String, bar: String})).to eq(QueryModel.new(id: 0_i64, foo: "foo", bar: "bar"))
    end
  end

  describe ".new" do
    it "creates a new instance" do
      expect(FooBarModel.new.foo).to eq("Foo")
    end

    it "bulk assigns properties" do
      expect(NotNilModel.new(val: "Val").val).to eq("Val")
    end

    it "bulk assigns properties" do
      expect(FooBarModel.new({"foo" => "Foo"}).foo).to eq("Foo")
    end

    it "supports assignment of nil" do
      expect(FooBarModel.new(foo: nil).foo).to be_nil
    end

    let(foo_bar) { FooBarModel.new.save }
    let(not_nil) { NotNilModel.new(val: "Val").save }

    it "assigns belongs_to associations" do
      expect(NotNilModel.new(foo_bar: foo_bar).foo_bar_model_id).to eq(foo_bar.id)
    end

    it "assigns belongs_to associations" do
      expect(FooBarModel.new({"not_nil" => not_nil}).not_nil_model_id).to eq(not_nil.id)
    end

    it "raises an error if property type is wrong" do
      expect{NotNilModel.new(val: 1)}.to raise_error(Ktistec::Model::TypeError)
    end

    it "raises an error if property type is wrong" do
      expect{FooBarModel.new({"foo" => 2})}.to raise_error(Ktistec::Model::TypeError)
    end
  end

  describe "#assign" do
    it "bulk assigns properties" do
      expect(FooBarModel.new.assign(foo: "").foo).to eq("")
    end

    it "bulk assigns properties" do
      expect(NotNilModel.new(val: "").assign(val: "Val").val).to eq("Val")
    end

    it "bulk assigns properties" do
      expect(FooBarModel.new(foo: "").assign({"foo" => "Foo"}).foo).to eq("Foo")
    end

    it "supports assignment of nil" do
      expect(FooBarModel.new(foo: "Foo").assign(foo: nil).foo).to be_nil
    end

    let(foo_bar) { FooBarModel.new.save }

    it "assigns belongs_to associations" do
      expect(NotNilModel.new.assign(foo_bar: foo_bar).foo_bar_model_id).to eq(foo_bar.id)
    end

    let(not_nil) { NotNilModel.new(val: "Val").save }

    it "assigns has_one associations" do
      expect{foo_bar.assign(not_nil_model: not_nil)}.to change{not_nil.foo_bar_model_id}
    end

    it "assigns has_many associations" do
      expect{not_nil.assign(foo_bar_models: [foo_bar])}.to change{foo_bar.not_nil_model_id}
    end

    it "raises an error if property type is wrong" do
      expect{NotNilModel.new(val: "").assign(val: 1)}.to raise_error(Ktistec::Model::TypeError)
    end

    it "raises an error if property type is wrong" do
      expect{FooBarModel.new(foo: "").assign({"foo" => 2})}.to raise_error(Ktistec::Model::TypeError)
    end
  end

  describe "#==" do
    it "returns true if all properties are equal" do
      a = FooBarModel.new(foo: "Foo")
      b = FooBarModel.new(foo: "Foo")
      expect(a).to eq(b)
    end

    it "returns true if all properties are equal" do
      a = NotNilModel.new(val: "Val")
      b = NotNilModel.new(val: "Val")
      expect(a).to eq(b)
    end
  end

  describe "#hash" do
    it "returns the hash" do
      a = FooBarModel.new(foo: "Foo")
      b = FooBarModel.new(foo: "Foo")
      expect(a.hash).to eq(b.hash)
    end

    it "returns the hash" do
      a = NotNilModel.new(val: "Val")
      b = NotNilModel.new(val: "Val")
      expect(a.hash).to eq(b.hash)
    end
  end

  describe ".empty?" do
    it "returns true" do
      expect(FooBarModel.empty?).to be_true
    end

    it "returns true" do
      expect(NotNilModel.empty?).to be_true
    end
  end

  describe ".count" do
    before_each do
      FooBarModel.new.save
      NotNilModel.new(val: "Val").save
    end

    it "returns the count of persisted instances" do
      expect(FooBarModel.count).to eq(1)
    end

    it "returns the count of matching instances" do
      expect(FooBarModel.count(foo: "", bar: "")).to eq(0)
    end

    it "returns the count of matching instances" do
      expect(FooBarModel.count({"foo" => "", "bar" => ""})).to eq(0)
    end

    it "returns the count of persisted instances" do
      expect(NotNilModel.count).to eq(1)
    end

    it "returns the count of matching instances" do
      expect(NotNilModel.count(val: "")).to eq(0)
    end

    it "returns the count of matching instances" do
      expect(NotNilModel.count({"val" => ""})).to eq(0)
    end
  end

  describe ".all" do
    it "returns all persisted instances" do
      saved_model = FooBarModel.new.save
      expect(FooBarModel.all).to eq([saved_model])
    end

    it "returns all persisted instances" do
      saved_model = NotNilModel.new(val: "Val").save
      expect(NotNilModel.all).to eq([saved_model])
    end
  end

  describe ".find" do
    context "given the id" do
      it "finds the saved instance" do
        saved_model = FooBarModel.new.save
        expect(FooBarModel.find(saved_model.id)).to eq(saved_model)
      end

      it "finds the updated instance" do
        updated_model = FooBarModel.new.save.save
        expect(FooBarModel.find(updated_model.id)).to eq(updated_model)
      end

      it "finds the saved instance" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.find(saved_model.id)).to eq(saved_model)
      end

      it "raises an exception" do
        expect{NotNilModel.find(999999)}.to raise_error(Ktistec::Model::NotFound)
      end
    end

    context "given properties" do
      it "finds the saved instance" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.find(foo: "Foo", bar: "Bar")).to eq(saved_model)
      end

      it "finds the saved instance" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.find({"foo" => "Foo", "bar" => "Bar"})).to eq(saved_model)
      end

      it "finds the updated instance" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.find(foo: "Bar", bar: "Bar")).to eq(updated_model)
      end

      it "finds the updated instance" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.find({"foo" => "Bar", "bar" => "Bar"})).to eq(updated_model)
      end

      it "finds the saved instance" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.find(val: "Val")).to eq(saved_model)
      end

      it "finds the saved instance" do
        saved_model = NotNilModel.new({"val" => "Val"}).save
        expect(NotNilModel.find({"val" => "Val"})).to eq(saved_model)
      end

      it "raises an exception" do
        expect{NotNilModel.find(val: "Baz")}.to raise_error(Ktistec::Model::NotFound)
      end
    end

    context "given associations" do
      let!(not_nil_model) { NotNilModel.new(val: "Val").save }
      let!(foo_bar_model) { FooBarModel.new(not_nil: not_nil_model).save }

      it "finds the saved instance using the foreign key" do
        expect(FooBarModel.find(not_nil_model_id: not_nil_model.id)).to eq(foo_bar_model)
      end

      it "finds the saved instance using the foreign key" do
        expect(FooBarModel.find({"not_nil_model_id" => not_nil_model.id})).to eq(foo_bar_model)
      end

      it "finds the saved instance using the association" do
        expect(FooBarModel.find(not_nil: not_nil_model)).to eq(foo_bar_model)
      end

      it "finds the saved instance using the association" do
        expect(FooBarModel.find({"not_nil" => not_nil_model})).to eq(foo_bar_model)
      end
    end
  end

  describe ".find?" do
    it "returns nil" do
      expect{NotNilModel.find?(999999)}.to be_nil
    end

    it "returns nil" do
      expect{NotNilModel.find?(val: "Baz")}.to be_nil
    end

    it "returns nil" do
      expect{NotNilModel.find?({"val" => "Baz"})}.to be_nil
    end
  end

  describe ".where" do
    context "given properties" do
      it "returns the saved instances" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.where(foo: "Foo", bar: "Bar")).to eq([saved_model])
      end

      it "returns the saved instances" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.where({"foo" => "Foo", "bar" => "Bar"})).to eq([saved_model])
      end

      it "returns the saved instances" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.where("foo = ? and bar = ?", "Foo", "Bar")).to eq([saved_model])
      end

      it "returns the updated instances" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.where(foo: "Bar")).to eq([updated_model])
      end

      it "returns the updated instances" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.where({"foo" => "Bar"})).to eq([updated_model])
      end

      it "returns the updated instances" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.where("foo = ?", "Bar")).to eq([updated_model])
      end

      it "returns the saved instances" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.where(val: "Val")).to eq([saved_model])
      end

      it "returns the saved instances" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.where({"val" => "Val"})).to eq([saved_model])
      end

      it "returns the saved instances" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.where("val = ?", "Val")).to eq([saved_model])
      end

      it "returns an empty collection" do
        expect(FooBarModel.where(foo: "Foo", bar: "Bar")).to be_empty
      end

      it "returns an empty collection" do
        expect(FooBarModel.where("foo = ? and bar = ?", "Foo", "Bar")).to be_empty
      end

      it "returns an empty collection" do
        expect(NotNilModel.where(val: "Val")).to be_empty
      end

      it "returns an empty collection" do
        expect(NotNilModel.where("val = ?", "Val")).to be_empty
      end
    end

    context "given associations" do
      let!(not_nil_model) { NotNilModel.new(val: "Val").save }
      let!(foo_bar_model) { FooBarModel.new(not_nil: not_nil_model).save }

      it "returns the saved instances using the foreign key" do
        expect(FooBarModel.where(not_nil_model_id: not_nil_model.id)).to eq([foo_bar_model])
      end

      it "returns the saved instances using the foreign key" do
        expect(FooBarModel.where({"not_nil_model_id" => not_nil_model.id})).to eq([foo_bar_model])
      end

      it "returns the saved instances using the association" do
        expect(FooBarModel.where(not_nil: not_nil_model)).to eq([foo_bar_model])
      end

      it "returns the saved instances using the association" do
        expect(FooBarModel.where({"not_nil" => not_nil_model})).to eq([foo_bar_model])
      end
    end
  end

  describe ".sql" do
    context "given a saved instance" do
      let!(saved_model) { NotNilModel.new(val: "Val").save }

      it "returns the saved instances" do
        expect(NotNilModel.sql("SELECT #{NotNilModel.columns} FROM #{NotNilModel.table_name} WHERE val = ?", "Val")).to eq([saved_model])
      end

      it "returns the saved instances" do
        expect(NotNilModel.sql("SELECT #{NotNilModel.columns} FROM #{NotNilModel.table_name} WHERE val = ?", ["Val"])).to eq([saved_model])
      end
    end

    it "returns an empty collection" do
      expect(NotNilModel.sql("SELECT #{NotNilModel.columns} FROM #{NotNilModel.table_name} WHERE val = ?", "Val")).to be_empty
    end

    it "returns an empty collection" do
      expect(NotNilModel.sql("SELECT #{NotNilModel.columns} FROM #{NotNilModel.table_name} WHERE val = ?", ["Val"])).to be_empty
    end
  end

  describe "#serialize_graph" do
    let(foo_bar) { FooBarModel.new }
    let(not_nil) { NotNilModel.new(val: "Val") }
    let(graph) do
      foo_bar.assign(not_nil: not_nil)
      not_nil.assign(foo_bar: foo_bar)
      UnionAssociationModel.new(model: foo_bar)
    end

    it "serializes the graph of models" do
      expect(graph.serialize_graph.map(&.model)).to eq([graph, foo_bar, not_nil])
    end

    it "skips associated instances" do
      expect(graph.serialize_graph(skip_associated: true).map(&.model)).to eq([graph])
    end
  end

  describe "#valid?" do
    it "performs the validations" do
      new_model = NotNilModel.new(key: "Test", val: "Test")
      expect(new_model.valid?).to be_false
      expect(new_model.errors).to eq({"instance" => ["key is equal to val"]})
    end

    it "performs the validations" do
      new_model = NotNilModel.new(key: "key", val: "val")
      expect(new_model.valid?).to be_false
      expect(new_model.errors).to eq({"key" => ["is not capitalized"], "val" => ["is not capitalized"]})
    end

    it "performs the validations even if unchanged if called directly" do
      new_model = NotNilModel.new(id: 9999_i64, key: "key", val: "val").tap(&.clear!)
      expect(new_model.valid?).to be_false
      expect(new_model.errors).to eq({"key" => ["is not capitalized"], "val" => ["is not capitalized"]})
    end

    it "passes the validations" do
      new_model = NotNilModel.new(key: "Key", val: "Val")
      expect(new_model.valid?).to be_true
      expect(new_model.errors).to be_empty
    end

    it "validates the associated instance" do
      not_nil_model = NotNilModel.new(val: "")
      foo_bar_model = FooBarModel.new(not_nil_model: not_nil_model)
      expect(foo_bar_model.valid?).to be_false
      expect(not_nil_model.errors).to eq({"val" => ["is not capitalized"]})
      expect(foo_bar_model.errors).to eq({"not_nil_model.val" => ["is not capitalized"]})
    end

    it "validates the associated instance" do
      foo_bar_model = FooBarModel.new(foo: "Quux", bar: "Quux")
      not_nil_model = NotNilModel.new(val: "Val", foo_bar_models: [foo_bar_model])
      expect(not_nil_model.valid?).to be_false
      expect(foo_bar_model.errors).to eq({"instance" => ["foo or bar is quux"]})
      expect(not_nil_model.errors).to eq({"foo_bar_models.0.instance" => ["foo or bar is quux"]})
    end

    it "does not validate the associated instance" do
      not_nil_model = NotNilModel.new(val: "")
      foo_bar_model = FooBarModel.new(not_nil_model: not_nil_model)
      expect(foo_bar_model.valid?(skip_associated: true)).to be_true
      expect(not_nil_model.errors).to be_empty
      expect(foo_bar_model.errors).to be_empty
    end

    it "does not validate the associated instance if it's unchanged" do
      not_nil_model = NotNilModel.new(id: 9999_i64, val: "").tap(&.clear!)
      foo_bar_model = FooBarModel.new(not_nil_model: not_nil_model)
      expect(foo_bar_model.valid?).to be_true
      expect(not_nil_model.errors).to be_empty
      expect(foo_bar_model.errors).to be_empty
    end

    context "before validate lifecycle callback" do
      class AllCapsModel < NotNilModel
        @@table_name = "not_nil_models"

        def before_validate
          @key = @key.try(&.upcase)
          @val = @val.try(&.upcase)
        end
      end

      it "runs the callback" do
        all_caps_model = AllCapsModel.new(key: "key", val: "val").tap(&.valid?)
        expect(all_caps_model.key).to eq("KEY")
        expect(all_caps_model.val).to eq("VAL")
      end

      it "runs the callbacks even if unchanged if called directly" do
        all_caps_model = AllCapsModel.new(id: 9999_i64, key: "key", val: "val").tap(&.clear!).tap(&.valid?)
        expect(all_caps_model.key).to eq("KEY")
        expect(all_caps_model.val).to eq("VAL")
      end

      it "does not run the callbacks on associated instance if it's unchanged" do
        all_caps_model = AllCapsModel.new(id: 9999_i64, key: "key", val: "val").tap(&.clear!)
        FooBarModel.new(not_nil_model: all_caps_model).valid?
        expect(all_caps_model.key).to eq("key")
        expect(all_caps_model.val).to eq("val")
      end
    end
  end

  describe "#save" do
    context "new instance" do
      it "saves a new instance" do
        new_model = FooBarModel.new
        expect{new_model.save}.to change{FooBarModel.count}.by(1)
      end

      it "assigns an id" do
        new_model = FooBarModel.new
        expect{new_model.save}.to change{new_model.id}
      end

      it "saves a new instance with an assigned id" do
        new_model = FooBarModel.new(id: 9999_i64)
        expect{new_model.save}.to change{FooBarModel.count}.by(1)
      end

      it "saves a new instance even if unchanged if saved directly" do
        new_model = FooBarModel.new(id: 9999_i64, foo: "Foo", bar: "Bar").tap(&.clear!)
        expect(new_model.changed?).to be_false
        expect{new_model.save}.to change{FooBarModel.find?(foo: "Foo", bar: "Bar")}
      end

      it "raises a validation exception" do
        new_model = NotNilModel.new(val: "")
        expect{new_model.save}.to raise_error(Ktistec::Model::Invalid)
        expect(new_model.errors).to have_key("val")
      end

      it "doesn't raise a validation exception" do
        new_model = NotNilModel.new(val: "")
        expect{new_model.save(skip_validation: true)}.not_to raise_error
        expect(new_model.errors).to be_empty
      end

      it "saves the properties" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.find(saved_model.id).foo).to eq("Foo")
        expect(FooBarModel.find(saved_model.id).bar).to eq("Bar")
      end

      it "saves the properties" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.find(saved_model.id).val).to eq("Val")
      end

      it "saves the associated instance" do
        another_model = AnotherModel.new(val: "Val")
        expect{DerivedModel.new(not_nil_model: another_model).save}.to change{AnotherModel.count}
      end

      it "doesn't save the associated instance" do
        another_model = AnotherModel.new(val: "Val")
        expect{DerivedModel.new(not_nil_model: another_model).save(skip_associated: true)}.not_to change{AnotherModel.count}
      end

      it "doesn't save the associated instance if it's unchanged" do
        another_model = AnotherModel.new(id: 9999_i64, val: "Val").tap(&.clear!)
        expect(another_model.changed?).to be_false
        expect{DerivedModel.new(not_nil_model: another_model).save}.not_to change{AnotherModel.count}
      end

      it "doesn't save the instance" do
        derived_model = DerivedModel.new(bar: "Bar", not_nil_model: AnotherModel.new(val: ""))
        expect{begin derived_model.save; rescue; end}.not_to change{DerivedModel.count(bar: "Bar")}
      end
    end

    context "existing instance" do
      it "does not save a new instance" do
        saved_model = FooBarModel.new.save
        expect{saved_model.save}.not_to change{FooBarModel.count}
      end

      it "does not assign an id" do
        saved_model = FooBarModel.new.save
        expect{saved_model.save}.not_to change{saved_model.id}
      end

      it "does not save a new instance with an assigned id" do
        saved_model = FooBarModel.new(id: 9999_i64).save
        expect{saved_model.save}.not_to change{FooBarModel.count}
      end

      it "updates the instance even if unchanged if saved directly" do
        saved_model = FooBarModel.new.save.assign(foo: "Foo", bar: "Bar").tap(&.clear!)
        expect(saved_model.changed?).to be_false
        expect{saved_model.save}.to change{FooBarModel.find?(foo: "Foo", bar: "Bar")}
      end

      it "raises a validation exception" do
        new_model = NotNilModel.new(val: "Val").save
        expect{new_model.assign(val: "").save}.to raise_error(Ktistec::Model::Invalid)
        expect(new_model.errors).to have_key("val")
      end

      it "doesn't raise a validation exception" do
        new_model = NotNilModel.new(val: "Val").save
        expect{new_model.assign(val: "").save(skip_validation: true)}.not_to raise_error
        expect(new_model.errors).to be_empty
      end

      it "updates the properties" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.find(updated_model.id).foo).to eq("Bar")
        expect(FooBarModel.find(updated_model.id).bar).to eq("Bar")
      end

      it "updates the properties" do
        updated_model = NotNilModel.new(val: "Val").save.assign(val: "Baz").save
        expect(NotNilModel.find(updated_model.id).val).to eq("Baz")
      end

      it "saves the associated instance" do
        another_model = AnotherModel.new(val: "Val")
        expect{DerivedModel.new.save.assign(not_nil_model: another_model).save}.to change{AnotherModel.count}
      end

      it "doesn't save the associated instance" do
        another_model = AnotherModel.new(val: "Val")
        expect{DerivedModel.new.save.assign(not_nil_model: another_model).save(skip_associated: true)}.not_to change{AnotherModel.count}
      end

      it "doesn't save the associated instance if it's unchanged" do
        another_model = AnotherModel.new(id: 9999_i64, val: "Val").tap(&.clear!)
        expect(another_model.changed?).to be_false
        expect{DerivedModel.new.save.assign(not_nil_model: another_model).save}.not_to change{AnotherModel.count}
      end

      it "doesn't save the instance" do
        derived_model = DerivedModel.new.save.assign(bar: "Bar", not_nil_model: AnotherModel.new(val: ""))
        expect{begin derived_model.save; rescue; end}.not_to change{DerivedModel.count(bar: "Bar")}
      end
    end

    context "before save lifecycle callback" do
      class AllCapsModel < NotNilModel
        @@table_name = "not_nil_models"

        def before_save
          @key = @key.try(&.upcase)
          @val = @val.try(&.upcase)
        end
      end

      it "runs the callback" do
        all_caps_model = AllCapsModel.new(key: "Key", val: "Val").save
        expect(all_caps_model.key).to eq("KEY")
        expect(all_caps_model.val).to eq("VAL")
      end

      it "runs the callbacks even if unchanged if called directly" do
        all_caps_model = AllCapsModel.new(id: 9999_i64, key: "Key", val: "Val").tap(&.clear!).save
        expect(all_caps_model.key).to eq("KEY")
        expect(all_caps_model.val).to eq("VAL")
      end

      it "does not run the callbacks on associated instance if it's unchanged" do
        all_caps_model = AllCapsModel.new(id: 9999_i64, key: "Key", val: "Val").tap(&.clear!)
        FooBarModel.new(not_nil_model: all_caps_model).save
        expect(all_caps_model.key).to eq("Key")
        expect(all_caps_model.val).to eq("Val")
      end
    end
  end

  describe "#destroy" do
    it "destroys the persisted instance" do
      saved_model = FooBarModel.new.save
      expect{saved_model.destroy}.to change{FooBarModel.count}.by(-1)
    end

    context "before destroy lifecycle callback" do
      class DestroyedAtModel < FooBarModel
        @@table_name = "foo_bar_models"

        @[Assignable]
        property destroyed_at : Time?

        def before_destroy
          @destroyed_at = Time.utc
        end
      end

      it "runs the callback" do
        destroyed_at_model = DestroyedAtModel.new.save
        expect{destroyed_at_model.destroy}.to change{destroyed_at_model.destroyed_at}
      end
    end
  end

  describe "#new_record?" do
    it "returns true if the record has not been saved" do
      expect(FooBarModel.new.new_record?).to be_true
    end

    it "returns false if the record has been saved" do
      expect(FooBarModel.new.save.new_record?).to be_false
    end
  end

  describe "#changed?" do
    let(not_nil_model) { NotNilModel.new(val: "Val") }

    it "returns true if the record is new" do
      expect(not_nil_model.changed?).to be_true
    end

    it "returns true if the record is new even if it was cleared" do
      expect(not_nil_model.tap(&.clear!).changed?).to be_true
    end

    it "returns false if the record has not been changed" do
      expect(not_nil_model.save.changed?).to be_false
    end

    it "returns true if the record has been changed" do
      expect(not_nil_model.save.assign(val: "Baz").changed?).to be_true
    end

    it "returns false if the record has been cleared after it was changed" do
      expect(not_nil_model.save.assign(val: "Baz").tap(&.clear!).changed?).to be_false
    end

    it "returns false if the record has been saved" do
      expect(not_nil_model.save.assign(val: "Baz").save.changed?).to be_false
    end

    it "returns false if the record has been saved" do
      expect(not_nil_model.save.tap(&.changed?).assign(val: "Baz").save.changed?).to be_false
    end

    context "given a saved record" do
      before_each { not_nil_model.save }

      it "returns false if queried" do
        expect(NotNilModel.all.any?(&.changed?)).to be_false
      end

      it "returns false if queried" do
        expect(NotNilModel.find(not_nil_model.id).changed?).to be_false
      end

      it "returns false if queried" do
        expect(NotNilModel.find(val: not_nil_model.val).changed?).to be_false
      end

      it "returns false if queried" do
        expect(NotNilModel.find({"val" => not_nil_model.val}).changed?).to be_false
      end

      it "returns false if queried" do
        expect(NotNilModel.where(val: not_nil_model.val).any?(&.changed?)).to be_false
      end

      it "returns false if queried" do
        expect(NotNilModel.where({"val" => not_nil_model.val}).any?(&.changed?)).to be_false
      end

      it "returns false if queried" do
        expect(NotNilModel.where("val = ?", not_nil_model.val).any?(&.changed?)).to be_false
      end
    end

    context "with inverse associations" do
      let(not_nil_model) { NotNilModel.new(val: "Val").save }

      pre_condition { expect(not_nil_model.changed?).to be_false }

      it "does not mark inverse record as changed" do
        expect{FooBarModel.new(not_nil_model: not_nil_model)}.not_to change{not_nil_model.changed?}
      end

      it "does not mark inverse record as changed" do
        expect{FooBarModel.new(not_nil: not_nil_model)}.not_to change{not_nil_model.changed?}
      end

      let(foo_bar_model) { FooBarModel.new.save }

      pre_condition { expect(foo_bar_model.changed?).to be_false }

      it "does not mark inverse record as changed" do
        expect{NotNilModel.new(foo_bar_models: [foo_bar_model])}.not_to change{foo_bar_model.changed?}
      end

      it "does not mark inverse record as changed" do
        expect{NotNilModel.new(foo_bar: foo_bar_model)}.not_to change{foo_bar_model.changed?}
      end
    end

    it "returns false if the property has not been changed" do
      expect(not_nil_model.save.assign(key: "Foo").changed?(:val)).to be_false
    end

    it "returns true if the property has been changed" do
      expect(not_nil_model.save.assign(key: "Foo").changed?(:key)).to be_true
    end

    it "returns false if the property has been cleared after it was changed" do
      expect(not_nil_model.save.assign(key: "Foo").tap(&.clear!(:key)).changed?(:key)).to be_false
    end

    it "returns true if the property has been changed" do
      expect(not_nil_model.save.assign(key: "Foo").tap(&.clear!(:val)).changed?(:key)).to be_true
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      saved_model = FooBarModel.new
      expect(saved_model.to_s).to match(/id=/)
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      saved_model = FooBarModel.new
      expect(saved_model.inspect).to match(/id=nil/)
    end
  end

  describe "#to_json" do
    it "returns the JSON representation" do
      saved_model = FooBarModel.new
      expect(saved_model.to_json).to match(/"id":null/)
    end
  end

  describe "#to_h" do
    it "returns the hash representation" do
      saved_model = FooBarModel.new
      expect(saved_model.to_h.to_a).to contain({"id", nil})
    end
  end

  context "derived properties" do
    let(derived) { DerivedModel.new(id: 13_i64, not_nil_model_id: 17_i64) }
    let(another) { AnotherModel.new(id: 17_i64, foo_bar_model_id: 13_i64, val: "Val") }

    it "sets the aliased property" do
      expect{derived.assign(index: 1_i64)}.to change{derived.not_nil_model_id}.to(1_i64)
      expect{another.assign(index: 1_i64)}.to change{another.foo_bar_model_id}.to(1_i64)
    end

    it "gets the aliased property" do
      expect(derived.index).to eq(17_i64)
      expect(another.index).to eq(13_i64)
    end

    context "when queried via the aliased property" do
      before_each do
        derived.save
        another.save
      end

      it "returns the model" do
        expect(DerivedModel.where(index: 17_i64)).to have(derived)
        expect(AnotherModel.where(index: 13_i64)).to have(another)
      end
    end
  end

  context "associations" do
    let(foo_bar) { FooBarModel.new(id: 13_i64) }
    let(not_nil) { NotNilModel.new(id: 17_i64, val: "Val") }
    let(union) { UnionAssociationModel.new }

    pre_condition do
      expect(foo_bar.not_nil?).to be_nil
      expect(foo_bar.not_nil_model?).to be_nil
      expect(not_nil.foo_bar?).to be_nil
      expect(not_nil.foo_bar_models).to be_empty
    end

    context "belongs_to" do
      it "assigns the associated instance" do
        (foo_bar.not_nil = not_nil) && foo_bar.save
        expect(foo_bar.not_nil).to eq(not_nil)
        expect(not_nil.foo_bar_models).to eq([foo_bar])
      end

      it "assigns the associated instance" do
        foo_bar.assign(not_nil: not_nil).save
        expect(foo_bar.not_nil).to eq(not_nil)
        expect(not_nil.foo_bar_models).to eq([foo_bar])
      end

      it "assigns the associated instance" do
        (not_nil.foo_bar = foo_bar) && not_nil.save
        expect(not_nil.foo_bar).to eq(foo_bar)
        expect(foo_bar.not_nil_model).to eq(not_nil)
      end

      it "assigns the associated instance" do
        not_nil.assign(foo_bar: foo_bar).save
        expect(not_nil.foo_bar).to eq(foo_bar)
        expect(foo_bar.not_nil_model).to eq(not_nil)
      end

      it "finds a deleted instance if explicitly specified" do
        not_nil.assign(foo_bar: foo_bar).save
        foo_bar.dup.delete
        expect(NotNilModel.find(not_nil.id).foo_bar?(include_deleted: true)).to eq(foo_bar)
      end

      it "finds a deleted instance if explicitly specified" do
        not_nil.assign(foo_bar: foo_bar).save
        foo_bar.dup.delete
        expect(NotNilModel.find(not_nil.id).foo_bar(include_deleted: true)).to eq(foo_bar)
      end

      it "finds an undone instance if explicitly specified" do
        not_nil.assign(foo_bar: foo_bar).save
        foo_bar.dup.undo
        expect(NotNilModel.find(not_nil.id).foo_bar?(include_undone: true)).to eq(foo_bar)
      end

      it "finds an undone instance if explicitly specified" do
        not_nil.assign(foo_bar: foo_bar).save
        foo_bar.dup.undo
        expect(NotNilModel.find(not_nil.id).foo_bar(include_undone: true)).to eq(foo_bar)
      end

      it "updates the foreign key when saved" do
        foo_bar.assign(not_nil: NotNilModel.new(val: "New"))
        expect{foo_bar.save}.to change{foo_bar.not_nil_model_id}
        expect(FooBarModel.find(foo_bar.id).not_nil_model_id).not_to be_nil
      end

      it "updates the foreign key when saved" do
        not_nil.assign(foo_bar: FooBarModel.new)
        expect{not_nil.save}.to change{not_nil.foo_bar_model_id}
        expect(NotNilModel.find(not_nil.id).foo_bar_model_id).not_to be_nil
      end
    end

    context "has_many" do
      it "assigns the inverse association" do
        not_nil.foo_bar_models = [foo_bar]
        expect(not_nil.foo_bar_models).to eq([foo_bar])
        expect(foo_bar.not_nil).to eq(not_nil)
      end

      it "assigns the inverse association" do
        not_nil.assign(foo_bar_models: [foo_bar])
        expect(not_nil.foo_bar_models).to eq([foo_bar])
        expect(foo_bar.not_nil).to eq(not_nil)
      end

      it "does not destroy unassociated instances on assignment" do
        new_foo_bar = FooBarModel.new
        not_nil.assign(foo_bar_models: [new_foo_bar]).save
        NotNilModel.find(not_nil.id).assign(foo_bar_models: [foo_bar]) # but don't save
        expect(NotNilModel.find(not_nil.id).foo_bar_models).to eq([new_foo_bar])
        expect(FooBarModel.count(not_nil_model_id: not_nil.id)).to eq(1)
      end

      it "destroys unassociated instances on assignment and save" do
        new_foo_bar = FooBarModel.new
        not_nil.assign(foo_bar_models: [new_foo_bar]).save
        NotNilModel.find(not_nil.id).assign(foo_bar_models: [foo_bar]).save
        expect(NotNilModel.find(not_nil.id).foo_bar_models).to eq([foo_bar])
        expect(FooBarModel.count(not_nil_model_id: not_nil.id)).to eq(1)
      end

      it "does not save through a destroyed instance" do
        not_nil.assign(foo_bar_models: [foo_bar])
        new_foo_bar_model = FooBarModel.new(not_nil_model: not_nil).save
        not_nil.destroy
        foo_bar.foo = "Changed"
        expect{new_foo_bar_model.save}.not_to change{FooBarModel.count(foo: "Changed")}
      end

      it "does not save through a deleted instance" do
        not_nil.assign(foo_bar_models: [foo_bar])
        new_foo_bar_model = FooBarModel.new(not_nil_model: not_nil).save
        not_nil.delete
        foo_bar.foo = "Changed"
        expect{new_foo_bar_model.save}.not_to change{FooBarModel.count(foo: "Changed")}
      end

      it "includes a deleted instance if explicitly specified" do
        not_nil.assign(foo_bar_models: [foo_bar]).save
        foo_bar.dup.delete
        expect(NotNilModel.find(not_nil.id).foo_bar_models(include_deleted: true)).to eq([foo_bar])
      end

      it "includes an undone instance if explicitly specified" do
        not_nil.assign(foo_bar_models: [foo_bar]).save
        foo_bar.dup.undo
        expect(NotNilModel.find(not_nil.id).foo_bar_models(include_undone: true)).to eq([foo_bar])
      end
    end

    context "has_one" do
      it "assigns the inverse association" do
        foo_bar.not_nil_model = not_nil
        expect(foo_bar.not_nil_model).to eq(not_nil)
        expect(not_nil.foo_bar).to eq(foo_bar)
      end

      it "assigns the inverse association" do
        foo_bar.assign(not_nil_model: not_nil)
        expect(foo_bar.not_nil_model).to eq(not_nil)
        expect(not_nil.foo_bar).to eq(foo_bar)
      end

      it "does not destroy unassociated instances on assignment" do
        new_not_nil = NotNilModel.new(val: "New")
        foo_bar.assign(not_nil_model: new_not_nil).save
        FooBarModel.find(foo_bar.id).assign(not_nil_model: not_nil) # don't save
        expect(NotNilModel.count(foo_bar_model_id: foo_bar.id)).to eq(1)
        expect(FooBarModel.find(foo_bar.id).not_nil_model).to eq(new_not_nil)
      end

      it "destroys unassociated instances on assignment and save" do
        new_not_nil = NotNilModel.new(val: "New")
        foo_bar.assign(not_nil_model: new_not_nil).save
        FooBarModel.find(foo_bar.id).assign(not_nil_model: not_nil).save
        expect(NotNilModel.count(foo_bar_model_id: foo_bar.id)).to eq(1)
        expect(FooBarModel.find(foo_bar.id).not_nil_model).to eq(not_nil)
      end

      it "does not save through a destroyed instance" do
        foo_bar.assign(not_nil: not_nil)
        new_not_nil_model = NotNilModel.new(val: "Val", foo_bar: foo_bar).save
        foo_bar.destroy
        not_nil.key = "Changed"
        expect{new_not_nil_model.save}.not_to change{NotNilModel.count(key: "Changed")}
      end

      it "does not save through a deleted instance" do
        foo_bar.assign(not_nil: not_nil)
        new_not_nil_model = NotNilModel.new(val: "Val", foo_bar: foo_bar).save
        foo_bar.delete
        not_nil.key = "Changed"
        expect{new_not_nil_model.save}.not_to change{NotNilModel.count(key: "Changed")}
      end

      it "finds a deleted instance if explicitly specified" do
        foo_bar.assign(not_nil_model: not_nil).save
        not_nil.dup.delete
        expect(FooBarModel.find(foo_bar.id).not_nil_model?(include_deleted: true)).to eq(not_nil)
      end

      it "finds a deleted instance if explicitly specified" do
        foo_bar.assign(not_nil_model: not_nil).save
        not_nil.dup.delete
        expect(FooBarModel.find(foo_bar.id).not_nil_model(include_deleted: true)).to eq(not_nil)
      end

      it "finds an undone instance if explicitly specified" do
        foo_bar.assign(not_nil_model: not_nil).save
        not_nil.dup.undo
        expect(FooBarModel.find(foo_bar.id).not_nil_model?(include_undone: true)).to eq(not_nil)
      end

      it "finds an undone instance if explicitly specified" do
        foo_bar.assign(not_nil_model: not_nil).save
        not_nil.dup.undo
        expect(FooBarModel.find(foo_bar.id).not_nil_model(include_undone: true)).to eq(not_nil)
      end
    end

    it "returns nil" do
      (foo_bar.not_nil_model_id = 999999) && foo_bar.save
      expect(foo_bar.not_nil_model?).to be_nil
      expect(not_nil.foo_bar_models).to be_empty
    end

    it "returns nil" do
      (not_nil.foo_bar_model_id = 999999) && not_nil.save
      expect(not_nil.foo_bar?).to be_nil
      expect(foo_bar.not_nil?).to be_nil
    end

    it "returns the correct instance" do
      not_nil.save
      expect(union.assign(model_id: not_nil.id).model).to eq(not_nil)
    end

    it "returns the correct instance" do
      foo_bar.save
      expect(union.assign(model_id: foo_bar.id).model).to eq(foo_bar)
    end
  end
end
