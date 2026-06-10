require "../../../src/rules/view/mention"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::Mention do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }
  let_build(:actor, named: author)

  let(mention_name) { "actor@test.test" }

  describe "registry" do
    it "is registered" do
      expect(Rules::View.registry).to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the mention notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Mention.to_s)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#project" do
    let_create!(:object, attributed_to: author)
    let_create!(:mention, named: nil, name: mention_name, href: actor.iri, subject: object)

    it "maps to the actor/object key" do
      expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
    end

    context "mentioning a remote actor" do
      let_build(:actor, named: stranger, local: false)
      let_create!(:mention, named: nil, name: "stranger@remote", href: stranger.iri, subject: object)

      it "maps only to the local actor's key" do
        expect(subject.project(object.iri)).to eq([{from_iri: actor.iri, to_iri: object.iri}])
      end
    end
  end

  describe "#membership" do
    context "given an object mentioning the actor" do
      let_create!(:object, attributed_to: author)
      let_create!(:mention, named: nil, name: mention_name, href: actor.iri, subject: object)
      let_create!(:create, named: activity, actor: author, object: object)

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end

      context "in the actor's inbox" do
        before_each { put_in_inbox(actor, activity) }

        it "selects the object" do
          expect(selected).to eq([{actor.iri, object.iri, object.created_at}])
        end

        context "whose delivering activity is undone" do
          before_each { activity.undo! }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "but is attributed to the actor" do
          before_each { object.assign(attributed_to: actor).save }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "that also replies to a post by the actor" do
          let_create!(:object, named: parent, attributed_to: actor)

          before_each { object.assign(in_reply_to: parent).save }

          it "does not select the object" do
            expect(selected_iris).not_to contain(object.iri)
          end
        end

        context "that replies to a post by another local account" do
          let(another) { register.actor }
          let_create!(:object, named: parent, attributed_to: another)

          before_each { object.assign(in_reply_to: parent).save }

          it "selects the object" do
            expect(selected_iris).to contain(object.iri)
          end
        end
      end

      context "in the actor's inbox" do
        let_create!(:announce, named: activity, actor: author, object: object)

        before_each { put_in_inbox(actor, activity) }

        it "selects the object" do
          expect(selected_iris).to contain(object.iri)
        end
      end

      context "in the actor's inbox" do
        let_create!(:update, named: activity, actor: author, object: object)

        before_each { put_in_inbox(actor, activity) }

        it "selects the object" do
          expect(selected_iris).to contain(object.iri)
        end
      end

      context "in the actor's outbox" do
        let_create!(:announce, named: activity, actor: actor, object: object)

        before_each { put_in_outbox(actor, activity) }

        it "does not select the object" do
          expect(selected_iris).not_to contain(object.iri)
        end
      end
    end

    context "given an object mentioning a remote actor" do
      let_build(:actor, named: stranger, local: false)
      let_create!(:object, attributed_to: author)
      let_create!(:mention, named: nil, name: "stranger@remote", href: stranger.iri, subject: object)
      let_create!(:create, named: activity, actor: author, object: object)

      before_each { put_in_inbox(actor, activity) }

      it "does not select the object" do
        expect(selected_iris).not_to contain(object.iri)
      end
    end

    context "when scoped" do
      let_create!(:object, attributed_to: author)
      let_create!(:mention, named: nil, name: mention_name, href: actor.iri, subject: object)
      let_create!(:create, named: activity, actor: author, object: object)

      before_each { put_in_inbox(actor, activity) }

      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: object.iri}))
          .to eq([{actor.iri, object.iri, object.created_at}])
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
