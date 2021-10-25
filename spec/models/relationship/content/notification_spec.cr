require "../../../../src/models/relationship/content/notification"

require "../../../spec_helper/factory"
require "../../../spec_helper/model"
require "../../../spec_helper/register"

Spectator.describe Relationship::Content::Notification do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: Factory.create(:activity).iri
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

    it "rejects missing activity" do
      new_relationship = described_class.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("activity")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe ".update_notifications" do
    let(owner) { register.actor }

    let_build(:object, attributed_to: owner)
    let_build(:create, actor: owner, object: object)
    let_build(:announce, actor: owner, object: object)
    let_build(:like, actor: owner, object: object)
    let_build(:follow, actor: owner, object: owner)
    let_build(:delete, actor: owner, object: object)
    let_build(:undo, actor: owner)

    context "given empty notifications" do
      pre_condition { expect(owner.notifications).to be_empty }

      it "does not add the create to the notifications" do
        put_in_inbox(owner, create)
        described_class.update_notifications(owner, create)
        expect(owner.notifications).to be_empty
      end

      it "adds the announce to the notifications" do
        put_in_inbox(owner, announce)
        described_class.update_notifications(owner, announce)
        expect(owner.notifications).to eq([announce])
      end

      it "adds the like to the notifications" do
        put_in_inbox(owner, like)
        described_class.update_notifications(owner, like)
        expect(owner.notifications).to eq([like])
      end

      it "adds the follow to the notifications" do
        put_in_inbox(owner, follow)
        described_class.update_notifications(owner, follow)
        expect(owner.notifications).to eq([follow])
      end

      context "object mentions the owner" do
        before_each do
          object.assign(mentions: [
            Factory.build(:mention, name: owner.iri, href: owner.iri)
          ])
        end

        it "adds the create to the notifications" do
          put_in_inbox(owner, create)
          described_class.update_notifications(owner, create)
          expect(owner.notifications).to eq([create])
        end
      end

      context "object is not attributed to the owner" do
        let_build(:actor, named: :other)

        before_each { object.assign(attributed_to: other) }

        it "does not add the announce to the notifications" do
          put_in_inbox(owner, announce)
          described_class.update_notifications(owner, announce)
          expect(owner.notifications).to be_empty
        end

        it "does not add the like to the notifications" do
          put_in_inbox(owner, like)
          described_class.update_notifications(owner, like)
          expect(owner.notifications).to be_empty
        end
      end

      context "follow does not follow the owner" do
        let_build(:actor, named: :other)

        before_each { follow.assign(object: other) }

        it "does not add the follow to the notifications" do
          put_in_inbox(owner, follow)
          described_class.update_notifications(owner, follow)
          expect(owner.notifications).to be_empty
        end
      end
    end

    context "given notifictions with create already present" do
      let_build(:mention, name: owner.iri, href: owner.iri)

      before_each do
        object.assign(mentions: [mention])
        put_in_inbox(owner, create)
        put_in_notifications(owner, create)
      end

      pre_condition { expect(owner.notifications).to eq([create]) }

      it "does not add the create to the notifications" do
        put_in_inbox(owner, create)
        described_class.update_notifications(owner, create)
        expect(owner.notifications).to eq([create])
      end

      it "removes the create from the notifications" do
        put_in_inbox(owner, delete)
        described_class.update_notifications(owner, delete)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the create from the notifications" do
        put_in_inbox(owner, undo)
        described_class.update_notifications(owner, undo)
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end
    end

    context "given notifictions with announce already present" do
      before_each do
        undo.assign(object: announce)
        put_in_inbox(owner, announce)
        put_in_notifications(owner, announce)
      end

      pre_condition { expect(owner.notifications).to eq([announce]) }

      it "does not add the announce to the notifications" do
        put_in_inbox(owner, announce)
        described_class.update_notifications(owner, announce)
        expect(owner.notifications).to eq([announce])
      end

      it "removes the announce from the notifications" do
        put_in_inbox(owner, undo)
        described_class.update_notifications(owner, undo)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the announce from the notifications" do
        put_in_inbox(owner, delete)
        described_class.update_notifications(owner, delete)
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end
    end

    context "given notifictions with like already present" do
      before_each do
        undo.assign(object: like)
        put_in_inbox(owner, like)
        put_in_notifications(owner, like)
      end

      pre_condition { expect(owner.notifications).to eq([like]) }

      it "does not add the like to the notifications" do
        put_in_inbox(owner, like)
        described_class.update_notifications(owner, like)
        expect(owner.notifications).to eq([like])
      end

      it "removes the like from the notifications" do
        put_in_inbox(owner, undo)
        described_class.update_notifications(owner, undo)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the announce from the notifications" do
        put_in_inbox(owner, delete)
        described_class.update_notifications(owner, delete)
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end
    end

    context "given notifictions with follow already present" do
      before_each do
        undo.assign(object: follow)
        put_in_inbox(owner, follow)
        put_in_notifications(owner, follow)
      end

      pre_condition { expect(owner.notifications).to eq([follow]) }

      it "does not add the follow to the notifications" do
        put_in_inbox(owner, follow)
        described_class.update_notifications(owner, follow)
        expect(owner.notifications).to eq([follow])
      end

      it "removes the follow from the notifications" do
        put_in_inbox(owner, undo)
        described_class.update_notifications(owner, undo)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end

      it "does not remove the announce from the notifications" do
        put_in_inbox(owner, delete)
        described_class.update_notifications(owner, delete)
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end
    end

    # currently, this is the common case for mailbox handlng right
    # now. the object is placed in the mailbox, the object is deleted.
    # since it is deletable it no longer appears in model queries.
    # ensure that the corresponding notification is removed
    # nonetheless.

    context "given notifications with an object that has been destroyed" do
      before_each do
        put_in_inbox(owner, delete)
        put_in_notifications(owner, create)
        object.destroy
      end

      pre_condition do
        expect(described_class.where(from_iri: owner.iri)).not_to be_empty
      end

      # a copy without the associated object attached
      let(delete_fresh) { ActivityPub::Activity::Delete.find(delete.id) }

      it "destroys the notification" do
        described_class.update_notifications(owner, delete_fresh)
        expect(described_class.where(from_iri: owner.iri)).to be_empty
      end
    end
  end
end
