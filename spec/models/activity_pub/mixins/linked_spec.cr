require "../../../../src/models/activity_pub/mixins/linked"

require "../../../spec_helper/base"
require "../../../spec_helper/key_pair"
require "../../../spec_helper/network"

class LinkedModel
  include Ktistec::Model(Linked)

  @[Persistent]
  property linked_model_iri : String?

  belongs_to linked_model, foreign_key: linked_model_iri, primary_key: iri

  def self.from_json_ld?(json_ld)
  end
end

Spectator.describe Ktistec::Model::Linked do
  setup_spec

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
        iri: "https://test.test/objects/subject"
      )
    end
    let(object) do
      LinkedModel.new(
        iri: "https://remote/objects/object"
      )
    end
    let(key_pair) do
      KeyPair.new("https://key_pair")
    end

    # linked object is not dereferenced.

    context "when linked object is local" do
      before_each { subject.linked_model_iri = "https://test.test/objects/object" }

      it "does not fetch the linked model instance" do
        subject.linked_model?(key_pair, dereference: false)
        expect(HTTP::Client.last?).to be_nil
      end

      it "does not fetch the linked model instance" do
        subject.linked_model?(key_pair, dereference: true)
        expect(HTTP::Client.last?).to be_nil
      end
    end

    context "when linked object is remote" do
      before_each { subject.linked_model_iri = "https://remote/objects/object" }

      it "does not fetch the linked model instance" do
        subject.linked_model?(key_pair, dereference: false)
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches the linked model instance" do
        subject.linked_model?(key_pair, dereference: true)
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end

      context "when object is cached" do
        before_each { object.save }

        it "does not fetch the linked model instance" do
          subject.linked_model?(key_pair, dereference: true, ignore_cached: false)
          expect(HTTP::Client.last?).to be_nil
        end

        it "fetches the linked model instance" do
          subject.linked_model?(key_pair, dereference: true, ignore_cached: true)
          expect(HTTP::Client.last?).to match("GET #{object.iri}")
        end
      end
    end

    # linked object is already dereferenced.

    context "when linked object is cached and unchanged" do
      before_each { subject.linked_model = object.save }

      pre_condition { expect(object.changed?).to be_false }

      it "does not fetch the linked model instance" do
        subject.linked_model?(key_pair, dereference: true, ignore_cached: false)
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches the linked model instance" do
        subject.linked_model?(key_pair, dereference: true, ignore_cached: true)
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end
    end

    context "when linked object is changed" do
      before_each { subject.linked_model = object }

      pre_condition { expect(object.changed?).to be_true }

      it "does not fetch the linked model instance" do
        subject.linked_model?(key_pair, dereference: true, ignore_changed: false)
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches the linked model instance" do
        subject.linked_model?(key_pair, dereference: true, ignore_changed: true)
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end
    end
  end

  describe ".dereference?" do
    let(subject) do
      LinkedModel
    end
    let(object) do
      LinkedModel.new(
        iri: "https://remote/objects/object"
      )
    end
    let(key_pair) do
      KeyPair.new("https://key_pair")
    end

    context "when linked object is local" do
      let(object_iri) { "https://test.test/objects/object" }

      it "does not fetch the object" do
        subject.dereference?(key_pair, object_iri)
        expect(HTTP::Client.last?).to be_nil
      end
    end

    context "when linked object is remote" do
      let(object_iri) { "https://remote/objects/object" }

      it "fetches the object" do
        subject.dereference?(key_pair, object_iri)
        expect(HTTP::Client.last?).to match("GET #{object_iri}")
      end

      context "when object is cached" do
        before_each { object.save }

        it "does not fetch the object" do
          subject.dereference?(key_pair, object_iri, ignore_cached: false)
          expect(HTTP::Client.last?).to be_nil
        end

        it "fetches the object" do
          subject.dereference?(key_pair, object_iri, ignore_cached: true)
          expect(HTTP::Client.last?).to match("GET #{object_iri}")
        end
      end
    end
  end

  describe "#origin" do
    it "returns the origin" do
      expect(LinkedModel.new(iri: "https://test.test/foo_bar").origin).to eq("https://test.test")
      expect(LinkedModel.new(iri: "https://remote/foo_bar").origin).to eq("https://remote")
    end
  end

  describe "#uid" do
    it "returns the unique identifier" do
      expect(LinkedModel.new(iri: "https://test.test/foo_bar").uid).to eq("foo_bar")
      expect(LinkedModel.new(iri: "https://remote/foo_bar").uid).to eq("foo_bar")
    end
  end

  describe "#local?" do
    it "indicates if the instance is local" do
      expect(LinkedModel.new(iri: "https://test.test/foo_bar").local?).to be_true
      expect(LinkedModel.new(iri: "https://remote/foo_bar").local?).to be_false
    end
  end

  describe "#cached?" do
    it "indicates if the instance is cached" do
      expect(LinkedModel.new(iri: "https://test.test/foo_bar").cached?).to be_false
      expect(LinkedModel.new(iri: "https://remote/foo_bar").cached?).to be_true
    end
  end
end
