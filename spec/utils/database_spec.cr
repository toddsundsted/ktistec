require "../../src/utils/database"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Ktistec::Database do
  setup_spec

  describe ".recreate_timeline_and_notifications" do
    let(owner) { register.actor }

    let_build(:actor, named: other)

    context "given notifications" do
      let_build(:object, named: object1, attributed_to: owner)
      let_create(:announce, named: announce1, actor: owner, object: object1)
      let_build(:object, named: object2, attributed_to: other)
      let_create(:announce, named: announce2, actor: other, object: object2)
      let_build(:object, named: object3, attributed_to: owner)
      let_create(:announce, named: announce3, actor: owner, object: object3)

      before_each do
        put_in_inbox(owner, announce1)
        put_in_notifications(owner, announce1)
        put_in_notifications(owner, announce2)
        put_in_inbox(owner, announce3)
      end

      pre_condition { expect(owner.notifications).to contain_exactly(announce1, announce2).in_any_order }

      it "leaves entries that belong" do
        Ktistec::Database.recreate_timeline_and_notifications
        expect(owner.notifications).to have(announce1)
      end

      it "removes entries that don't belong" do
        Ktistec::Database.recreate_timeline_and_notifications
        expect(owner.notifications).not_to have(announce2)
      end

      it "adds entries that are missing" do
        Ktistec::Database.recreate_timeline_and_notifications
        expect(owner.notifications).to have(announce3)
      end
    end

    context "given a timeline" do
      let_build(:object, named: object1, attributed_to: owner)
      let_create(:create, named: create1, actor: owner, object: object1)
      let_build(:object, named: object2, attributed_to: other)
      let_create(:create, named: create2, actor: other, object: object2)
      let_build(:object, named: object3, attributed_to: owner)
      let_create(:create, named: create3, actor: owner, object: object3)

      before_each do
        put_in_inbox(owner, create1)
        put_in_timeline(owner, object1)
        put_in_timeline(owner, object2)
        put_in_inbox(owner, create3)
      end

      pre_condition { expect(owner.timeline).to contain_exactly(object1, object2).in_any_order }

      it "leaves entries that belong" do
        Ktistec::Database.recreate_timeline_and_notifications
        expect(owner.timeline).to have(object1)
      end

      it "removes entries that don't belong" do
        Ktistec::Database.recreate_timeline_and_notifications
        expect(owner.timeline).not_to have(object2)
      end

      it "adds entries that are missing" do
        Ktistec::Database.recreate_timeline_and_notifications
        expect(owner.timeline).to have(object3)
      end
    end
  end
end
