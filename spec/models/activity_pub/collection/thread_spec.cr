require "../../../../src/models/activity_pub/collection/thread"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Collection::Thread do
  setup_spec

  describe ".find_or_create" do
    let_create!(:object, named: :origin)
    let_create!(:object, named: :reply, in_reply_to_iri: origin.iri)

    context "given an existing collection for thread" do
      let_create!(:collection, named: existing, iri: origin.thread)

      it "finds the existing collection" do
        expect(described_class.find_or_create(thread: origin.thread)).to eq(existing)
      end

      it "finds the existing collection" do
        expect(described_class.find_or_create(thread: reply.thread)).to eq(existing)
      end
    end
  end

  describe ".merge_into" do
    let_create!(:collection)

    it "updates iri if thread changes" do
      expect{described_class.merge_into(collection.iri, "https://new_thread")}.to change{collection.reload!.iri}.to("https://new_thread")
    end

    context "given an existing collection for thread" do
      let_create!(:collection, named: existing, iri: "https://new_thread")

      it "merges the collection" do
        expect{described_class.merge_into(collection.iri, existing.iri)}.to change{ActivityPub::Collection.count}.by(-1)
      end

      it "destroys the collection that is merged from" do
        expect{described_class.merge_into(collection.iri, existing.iri)}.to change{ActivityPub::Collection.find?(collection.id)}.to(nil)
      end

      it "does not destroy the collection that is merged to" do
        expect{described_class.merge_into(collection.iri, existing.iri)}.not_to change{ActivityPub::Collection.find?(existing.id)}.from(existing)
      end
    end
  end
end

Spectator.describe ActivityPub::Object do
  setup_spec

  context "given a collection" do
    let_build(:object)
    let_create!(:collection, named: nil, iri: object.save.thread)

    def all_collections ; ActivityPub::Collection.all end

    it "updates collections when thread changes" do
      expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_collections.map(&.iri)}.to(["https://elsewhere"])
    end

    context "given an existing collection" do
      let_create!(:collection, named: nil, iri: "https://elsewhere")

      it "updates collection when thread changes" do
        expect{object.assign(in_reply_to_iri: "https://elsewhere").save}.to change{all_collections.map(&.iri)}.to(["https://elsewhere"])
      end
    end
  end
end
