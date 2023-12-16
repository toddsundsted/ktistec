require "../../../../src/models/activity_pub/mixins/linked"

require "../../../spec_helper/base"
require "../../../spec_helper/key_pair"
require "../../../spec_helper/network"

Spectator.describe Ktistec::Model::Linked do
  setup_spec

  class LinkedModel
    include Ktistec::Model(Linked, Deletable)
    include ActivityPub

    @@table_name = "linked_models"

    @[Persistent]
    property linked_model_iri : String?

    belongs_to linked_model, class_name: {{@type}}, foreign_key: linked_model_iri, primary_key: iri

    def to_json_ld(**options)
      %Q|{"@type":"LinkedModel","@id":"#{iri}"}|
    end

    def self.map(json, **options)
      Hash(String, String).new
    end
  end

  before_each do
    Ktistec.database.exec <<-SQL
      CREATE TABLE linked_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        iri varchar(255) NOT NULL,
        linked_model_iri text,
        deleted_at datetime
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
    class BlankModel
      include Ktistec::Model(Linked)

      @@required_iri = false
    end

    it "may be absent" do
      expect(BlankModel.new.valid?).to be_true
    end

    before_each { LinkedModel.new(iri: "http://test.test/linked").save }

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
    let(key_pair) do
      KeyPair.new("https://key_pair")
    end

    it "does not fetch and does not return the object" do
      expect(subject.linked_model?(key_pair, dereference: false)).to be_nil
      expect(HTTP::Client.last?).to be_nil
    end

    it "fetches but does not return the object" do
      expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: false)).to be_nil
      expect(HTTP::Client.last?).to match("GET #{object.iri}")
    end

    it "fetches but does not return the object" do
      expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: true)).to be_nil
      expect(HTTP::Client.last?).to match("GET #{object.iri}")
    end

    context "when linked object is local" do
      before_each do
        object.assign(iri: "https://test.test/objects/object").save
        subject.linked_model_iri = object.iri
      end

      it "returns but does not fetch the object" do
        expect(subject.linked_model?(key_pair, dereference: false)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      it "returns but does not fetch the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: false)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      it "returns but does not fetch the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: true)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end
    end

    context "when linked object is remote" do
      before_each do
        HTTP::Client.objects << object
        subject.linked_model_iri = object.iri
      end

      it "does not fetch and does not return the object" do
        expect(subject.linked_model?(key_pair, dereference: false)).to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches and returns the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: false)).not_to be_nil
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end

      it "fetches and returns the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: false)).not_to be_nil
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end

      context "when object is cached" do
        before_each { object.save }

        it "returns but does not fetch the object" do
          expect(subject.linked_model?(key_pair, dereference: false)).not_to be_nil
          expect(HTTP::Client.last?).to be_nil
        end

        it "returns but does not fetch the object" do
          expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: false)).not_to be_nil
          expect(HTTP::Client.last?).to be_nil
        end

        it "fetches and returns the object" do
          expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: true)).not_to be_nil
          expect(HTTP::Client.last?).to match("GET #{object.iri}")
        end
      end
    end

    context "when linked object is cached and unchanged" do
      before_each do
        HTTP::Client.objects << object
        subject.linked_model = object.save
      end

      pre_condition { expect(object.changed?).to be_false }

      it "returns but does not fetch the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: false)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches and returns the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_cached: true)).not_to be_nil
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end
    end

    context "when linked object is changed" do
      before_each do
        HTTP::Client.objects << object
        subject.linked_model = object
      end

      pre_condition { expect(object.changed?).to be_true }

      it "returns but does not fetch the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_changed: false)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      it "fetches and returns the object" do
        expect(subject.linked_model?(key_pair, dereference: true, ignore_changed: true)).not_to be_nil
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

    it "fetches but does not return the object" do
      expect(subject.dereference?(key_pair, object.iri, ignore_cached: false)).to be_nil
      expect(HTTP::Client.last?).to match("GET #{object.iri}")
    end

    it "fetches but does not return the object" do
      expect(subject.dereference?(key_pair, object.iri, ignore_cached: true)).to be_nil
      expect(HTTP::Client.last?).to match("GET #{object.iri}")
    end

    context "when linked object is local" do
      before_each { object.assign(iri: "https://test.test/objects/object").save }

      it "returns but does not fetch the object" do
        expect(subject.dereference?(key_pair, object.iri, ignore_cached: false)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      it "returns but does not fetch the object" do
        expect(subject.dereference?(key_pair, object.iri, ignore_cached: true)).not_to be_nil
        expect(HTTP::Client.last?).to be_nil
      end

      context "when object is deleted" do
        before_each { object.delete! }

        it "does not return and does not fetch the object" do
          expect(subject.dereference?(key_pair, object.iri, include_deleted: false)).to be_nil
          expect(HTTP::Client.last?).to be_nil
        end

        it "returns but does not fetch the object" do
          expect(subject.dereference?(key_pair, object.iri, include_deleted: true)).not_to be_nil
          expect(HTTP::Client.last?).to be_nil
        end
      end
    end

    context "when linked object is remote" do
      before_each { HTTP::Client.objects << object }

      it "fetches and returns the object" do
        expect(subject.dereference?(key_pair, object.iri, ignore_cached: false)).not_to be_nil
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end

      it "fetches and returns the object" do
        expect(subject.dereference?(key_pair, object.iri, ignore_cached: true)).not_to be_nil
        expect(HTTP::Client.last?).to match("GET #{object.iri}")
      end

      context "when object is cached" do
        before_each { object.save }

        it "returns but does not fetch the object" do
          expect(subject.dereference?(key_pair, object.iri, ignore_cached: false)).not_to be_nil
          expect(HTTP::Client.last?).to be_nil
        end

        it "fetches and returns the object" do
          expect(subject.dereference?(key_pair, object.iri, ignore_cached: true)).not_to be_nil
          expect(HTTP::Client.last?).to match("GET #{object.iri}")
        end

        context "when object is deleted" do
          before_each { object.delete! }

          it "fetches and returns the object" do
            expect(subject.dereference?(key_pair, object.iri, include_deleted: false)).not_to be_nil
            expect(HTTP::Client.last?).to match("GET #{object.iri}")
          end

          it "returns but does not fetch the object" do
            expect(subject.dereference?(key_pair, object.iri, include_deleted: true)).not_to be_nil
            expect(HTTP::Client.last?).to be_nil
          end
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
