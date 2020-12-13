require "../../../src/framework/model/linked"

require "../../spec_helper/base"
require "../../spec_helper/network"

class LinkedModel
  include Ktistec::Model(Linked)

  @[Persistent]
  property linked_model_iri : String?

  belongs_to linked_model, foreign_key: linked_model_iri, primary_key: iri

  def self.from_json_ld?(json_ld)
  end
end

Spectator.describe Ktistec::Model::Linked do
  before_each { HTTP::Client.reset }

  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE linked_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        iri varchar(255) NOT NULL,
        linked_model_iri text
      )
    SQL
  end
  after_each do
    Ktistec.database.exec "DROP TABLE linked_models"
  end

  describe ".new" do
    it "includes Ktistec::Model::Linked" do
      expect(LinkedModel.new).to be_a(Ktistec::Model::Linked)
    end
  end

  describe "validation" do
    subject! { LinkedModel.new(iri: "http://test.test/linked").save }

    it "must be present" do
      expect(LinkedModel.new.valid?).to be_false
    end

    it "must be an absolute URI" do
      expect(LinkedModel.new(iri: "/some_thing").valid?).to be_false
    end

    it "must be unique" do
      expect(LinkedModel.new(iri: "http://test.test/linked").valid?).to be_false
    end

    it "is valid" do
      expect(LinkedModel.new(iri: "http://test.test/other").valid?).to be_true
    end
  end

  describe "the generated accessor" do
    let(subject) do
      LinkedModel.new(
        iri: "https://test.test/objects/subject",
        linked_model_iri: "https://remote/objects/object"
      )
    end
    let(object) do
      LinkedModel.new(
        iri: "https://remote/objects/object"
      )
    end

    context "when object is saved" do
      before_each { object.save }

      it "does not fetch the linked model instance" do
        subject.linked_model?(dereference: true)
        expect(HTTP::Client.last?).to be_nil
      end
    end

    context "when object is local" do
      before_each { subject.linked_model_iri = "https://test.test/objects/object" }

      it "does not fetch the linked model instance" do
        subject.linked_model?(dereference: true)
        expect(HTTP::Client.last?).to be_nil
      end
    end

    context "when object is remote" do
      it "fetches the linked model instance" do
        subject.linked_model?(dereference: true)
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end

      it "does not fetch the linked model instance" do
        subject.linked_model?(dereference: false)
        expect(HTTP::Client.last?).to be_nil
      end
    end
  end

  describe "#local" do
    it "indicates if the instance is local" do
      expect(LinkedModel.new(iri: "https://test.test/foo_bar").local).to be_true
      expect(LinkedModel.new(iri: "https://remote/foo_bar").local).to be_false
    end
  end
end
