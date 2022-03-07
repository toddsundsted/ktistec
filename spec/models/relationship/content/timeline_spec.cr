require "../../../../src/models/relationship/content/timeline"

require "../../../spec_helper/factory"
require "../../../spec_helper/model"

Spectator.describe Relationship::Content::Timeline do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: Factory.create(:object).iri
    }
  end

  context "creation" do
    let(relationship) { described_class.new(**options).save }

    it "creates confirmed relationships by default" do
      expect(relationship.confirmed).to be_true
    end
  end

  context "validation" do
    it "rejects missing owner" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("owner")
    end

    it "rejects missing object" do
      new_relationship = described_class.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("object")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe ".update_timeline" do
    let(owner) { register.actor }

    let_build(:object, attributed_to: owner)
    let_build(:create, actor: owner, object: object)
    let_build(:announce, actor: owner, object: object)
    let_build(:delete, actor: owner, object: object)
    let_build(:undo, actor: owner, object: announce)

    context "given an empty timeline" do
      pre_condition { expect(owner.timeline).to be_empty }

      it "adds the object to the timeline" do
        put_in_outbox(owner, create)
        described_class.update_timeline(owner, create)
        expect(owner.timeline).to eq([object])
      end

      it "adds the object to the timeline" do
        put_in_outbox(owner, announce)
        described_class.update_timeline(owner, announce)
        expect(owner.timeline).to eq([object])
      end

      context "object is a reply" do
        let_build(:object, named: :original, attributed_to: owner)

        before_each { object.in_reply_to = original }

        it "does not add the object to the timeline" do
          put_in_outbox(owner, create)
          described_class.update_timeline(owner, create)
          expect(owner.timeline).to be_empty
        end

        it "adds the object to the timeline" do
          put_in_outbox(owner, announce)
          described_class.update_timeline(owner, announce)
          expect(owner.timeline).to eq([object])
        end
      end
    end

    context "given a timeline with an object added by create" do
      before_each do
        put_in_outbox(owner, create)
        described_class.update_timeline(owner, create)
      end

      pre_condition { expect(owner.timeline).to eq([object]) }

      it "does not add the object to the timeline again" do
        put_in_outbox(owner, create)
        described_class.update_timeline(owner, create)
        expect(owner.timeline).to eq([object])
      end

      it "deletes the object from the timeline" do
        put_in_outbox(owner, delete)
        object.delete
        described_class.update_timeline(owner, delete)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end

      it "does not delete the object from the timeline" do
        put_in_outbox(owner, undo)
        announce.undo
        described_class.update_timeline(owner, undo)
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end
    end

    context "given a timeline with an object added by announce" do
      before_each do
        put_in_outbox(owner, announce)
        described_class.update_timeline(owner, announce)
      end

      pre_condition { expect(owner.timeline).to eq([object]) }

      it "does not add the object to the timeline again" do
        put_in_outbox(owner, announce)
        described_class.update_timeline(owner, announce)
        expect(owner.timeline).to eq([object])
      end

      it "deletes the object from the timeline" do
        put_in_outbox(owner, delete)
        object.delete
        described_class.update_timeline(owner, delete)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end

      it "deletes the object from the timeline" do
        put_in_outbox(owner, undo)
        announce.undo
        described_class.update_timeline(owner, undo)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end
    end

    # currently, this is the common case for mailbox handlng right
    # now. the object is placed in the mailbox, the object is deleted.
    # since it is deletable it no longer appears in model queries.
    # ensure that the corresponding timeline entry is removed
    # nonetheless.

    context "given a timeline with an object that has been destroyed" do
      before_each do
        put_in_outbox(owner, delete)
        put_in_timeline(owner, object)
        object.destroy
      end

      pre_condition do
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end

      # a copy without the associated object attached
      let(delete_fresh) { ActivityPub::Activity::Delete.find(delete.id) }

      it "destroys the timeline entry" do
        described_class.update_timeline(owner, delete_fresh)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end
    end

    # unlikely, but for consistency.

    context "given a timeline with an object that has been destroyed" do
      before_each do
        put_in_outbox(owner, undo)
        put_in_timeline(owner, object)
        object.destroy
      end

      pre_condition do
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end

      # a copy without the associated object attached
      let(undo_fresh) { ActivityPub::Activity::Undo.find(undo.id) }

      it "destroys the timeline entry" do
        described_class.update_timeline(owner, undo_fresh)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end
    end
  end
end
