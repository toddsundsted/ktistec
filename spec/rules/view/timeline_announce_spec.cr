require "../../../src/rules/view/timeline_announce"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::TimelineAnnounce do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }
  let_build(:actor, named: author)
  let_build(:actor, named: announcer)

  describe "registry" do
    it "is not registered" do
      expect(Rules::View.registry).not_to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the timeline announce relationship type" do
      expect(subject.type).to eq(Relationship::Content::Timeline::Announce.to_s)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#project" do
    let_create!(:object, attributed_to: author)
    let_create!(:announce, named: activity, actor: announcer, object: object)

    it "maps to no key" do
      expect(subject.project(object.iri)).to be_empty
    end

    context "given an announce in the actor's inbox" do
      before_each { put_in_inbox(actor, activity) }

      it "maps to the actor/object key" do
        expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
      end

      context "with the announce undone" do
        before_each { activity.undo! }

        it "maps to the actor/object key" do
          expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
        end
      end

      context "and in a another account's inbox" do
        let(other) { register.actor }

        before_each { put_in_inbox(other, activity) }

        it "maps to both actors' keys" do
          expect(subject.project(object.iri)).to contain_exactly(
            {from_iri: actor.iri, to_iri: object.iri},
            {from_iri: other.iri, to_iri: object.iri},
          )
        end
      end

      # the state account termination leaves behind: the account is
      # destroyed but the actor's mailbox relationships persist
      context "with the actor's account destroyed" do
        before_each { Account.find(iri: actor.iri).destroy }

        it "maps to no key" do
          expect(subject.project(object.iri)).to be_empty
        end
      end
    end

    context "given a create in the actor's inbox" do
      # the one type the membership references but the projection ignores
      let_create!(:create, named: create_activity, actor: author, object: object)

      before_each { put_in_inbox(actor, create_activity) }

      it "maps to no key" do
        expect(subject.project(object.iri)).to be_empty
      end
    end
  end

  describe "#membership" do
    context "given an announce of an object" do
      let_create!(:object, attributed_to: author)
      let_create!(:announce, named: activity, actor: announcer, object: object)

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end

      context "in the actor's inbox" do
        let_create!(:inbox_relationship, named: mailbox, owner: actor, activity: activity)

        it "selects the object" do
          expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
        end

        context "with the announce undone" do
          before_each { activity.undo! }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "with the object deleted" do
          before_each { object.delete! }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "with the author blocked" do
          before_each { author.block! }

          it "selects the object" do
            expect(selected_iris).to contain(object.iri)
          end
        end

        context "with the announcer blocked" do
          before_each { announcer.block! }

          it "selects the object" do
            expect(selected_iris).to contain(object.iri)
          end
        end

        context "with the actor's account destroyed" do
          before_each { Account.find(iri: actor.iri).destroy }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "of a reply" do
          let_create!(:object, named: parent, attributed_to: author)

          before_each { object.assign(in_reply_to: parent).save }

          it "selects the object" do
            expect(selected_iris).to contain(object.iri)
          end
        end

        context "that is announced again" do
          let_create!(:announce, named: newer, actor: author, object: object)
          let_create!(:inbox_relationship, named: newer_mailbox, owner: actor, activity: newer)

          it "selects the object at its first contribution" do
            expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
          end

          context "with the first announce undone" do
            before_each { activity.undo! }

            it "selects the object at its second contribution" do
              expect(selected).to eq([{actor.iri, object.iri, newer_mailbox.created_at}])
            end
          end
        end

        context "with a create of the object also in the actor's inbox" do
          let_create!(:create, named: create_activity, actor: author, object: object)
          let_create!(:inbox_relationship, named: nil, owner: actor, activity: create_activity)

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end

          context "with the create undone" do
            before_each { create_activity.undo! }

            it "selects the object" do
              expect(selected_iris).to contain(object.iri)
            end
          end

          context "with the announce undone" do
            before_each { activity.undo! }

            it "does not select the object" do
              expect(selected_iris).not_to contain(object.iri)
            end
          end

          context "where the object is a reply" do
            let_create!(:object, named: parent, attributed_to: author)

            before_each { object.assign(in_reply_to: parent).save }

            it "selects the object" do
              expect(selected_iris).to contain(object.iri)
            end
          end
        end
      end
    end

    context "given an announce of an object in the actor's outbox" do
      let_create!(:object, attributed_to: author)
      let_create!(:announce, named: activity, actor: actor, object: object)
      let_create!(:outbox_relationship, named: mailbox, owner: actor, activity: activity)

      it "selects the object" do
        expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
      end
    end

    context "when scoped" do
      let_create!(:object, attributed_to: author)
      let_create!(:announce, named: activity, actor: announcer, object: object)
      let_create!(:inbox_relationship, named: mailbox, owner: actor, activity: activity)

      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: object.iri}))
          .to eq([{actor.iri, object.iri, mailbox.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: actor.iri, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the key as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: object.iri})
        expect(args).to eq([actor.iri, object.iri])
      end
    end
  end
end
