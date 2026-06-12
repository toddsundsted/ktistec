require "../../../src/rules/view/timeline_create"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::TimelineCreate do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }
  let_build(:actor, named: author)

  describe "registry" do
    it "is registered" do
      expect(Rules::View.registry).to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the timeline create relationship type" do
      expect(subject.type).to eq(Relationship::Content::Timeline::Create.to_s)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#subjects" do
    it "publishes to the owner's timeline subject" do
      expect(subject.subjects("alice")).to eq(["/actors/alice/timeline"])
    end
  end

  describe "#project" do
    let_create!(:object, attributed_to: author)
    let_create!(:create, named: activity, actor: author, object: object)

    it "maps to no key" do
      expect(subject.project(object.iri)).to be_empty
    end

    context "given the create in the actor's inbox" do
      before_each { put_in_inbox(actor, activity) }

      it "maps to the actor/object key" do
        expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
      end

      context "with the create undone" do
        before_each { activity.undo! }

        it "maps to the actor/object key" do
          expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
        end
      end

      context "and in another account's inbox" do
        let(other) { register.actor }

        before_each { put_in_inbox(other, activity) }

        it "maps to both actors' keys" do
          expect(subject.project(object.iri)).to contain_exactly(
            {from_iri: actor.iri, to_iri: object.iri},
            {from_iri: other.iri, to_iri: object.iri},
          )
        end
      end

      # the state account termination leaves behind: the accounts row
      # is destroyed but the actor's mailbox rows persist
      context "with the actor's account destroyed" do
        before_each { Account.find(iri: actor.iri).destroy }

        it "maps to no key" do
          expect(subject.project(object.iri)).to be_empty
        end
      end
    end

    context "given an update in the actor's inbox" do
      let_create!(:update, named: update_activity, actor: author, object: object)

      before_each { put_in_inbox(actor, update_activity) }

      it "maps to the actor/object key" do
        expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
      end
    end

    context "given an announce in the actor's inbox" do
      # the sibling view's type; this view's projection ignores it
      let_create!(:announce, actor: author, object: object)

      before_each { put_in_inbox(actor, announce) }

      it "maps to no key" do
        expect(subject.project(object.iri)).to be_empty
      end
    end
  end

  describe "#membership" do
    context "given a create of an object" do
      let_create!(:object, attributed_to: author)
      let_create!(:create, named: activity, actor: author, object: object)

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end

      context "in the actor's inbox" do
        let_create!(:inbox_relationship, named: mailbox, owner: actor, activity: activity)

        it "selects the object" do
          expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
        end

        context "with the create undone" do
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

        context "with the actor's account destroyed" do
          before_each { Account.find(iri: actor.iri).destroy }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "mentioning another actor" do
          let_build(:actor, named: stranger, local: false)
          let_create!(:mention, named: nil, name: "stranger@remote", href: stranger.iri, subject: object)

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end

          context "and the actor" do
            let_create!(:mention, named: nil, name: "actor@test.test", href: actor.iri, subject: object)

            it "selects the object" do
              expect(selected_iris).to contain(object.iri)
            end
          end
        end

        context "that is updated later" do
          let_create!(:update, named: update_activity, actor: author, object: object)
          let_create!(:inbox_relationship, named: nil, owner: actor, activity: update_activity)

          it "selects the object at its first contribution" do
            expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
          end
        end

        context "of a reply" do
          let_create!(:object, named: parent, attributed_to: author)

          before_each { object.assign(in_reply_to: parent).save }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end

          context "mentioning the actor" do
            let_create!(:mention, named: nil, name: "actor@test.test", href: actor.iri, subject: object)

            it "selects the object" do
              expect(selected_iris).to contain(object.iri)
            end
          end

          context "by the actor" do
            before_each { object.assign(attributed_to: actor).save }

            it "selects the object" do
              expect(selected_iris).to contain(object.iri)
            end
          end
        end
      end
    end

    context "given an update of an object in the actor's inbox" do
      let_create!(:object, attributed_to: author)
      let_create!(:update, named: activity, actor: author, object: object)
      let_create!(:inbox_relationship, named: mailbox, owner: actor, activity: activity)

      it "selects the object" do
        expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
      end

      context "that is a reply" do
        let_create!(:object, named: parent, attributed_to: author)

        before_each { object.assign(in_reply_to: parent).save }

        it "does not select the object" do
          expect(selected_iris).not_to contain(object.iri)
        end

        context "mentioning the actor" do
          let_create!(:mention, named: nil, name: "actor@test.test", href: actor.iri, subject: object)

          it "selects the object" do
            expect(selected_iris).to contain(object.iri)
          end
        end
      end
    end

    context "given a create of the actor's own object in the outbox" do
      let_create!(:object, attributed_to: actor)
      let_create!(:create, named: activity, actor: actor, object: object)
      let_create!(:outbox_relationship, named: mailbox, owner: actor, activity: activity)

      it "selects the object" do
        expect(selected).to eq([{actor.iri, object.iri, mailbox.created_at}])
      end
    end

    context "when scoped" do
      let_create!(:object, attributed_to: author)
      let_create!(:create, named: activity, actor: author, object: object)
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
