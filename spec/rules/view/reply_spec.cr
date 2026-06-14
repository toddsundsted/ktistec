require "../../../src/rules/view/reply"
require "../../../src/models/relationship/content/notification/reply"
require "../../../src/models/activity_pub/activity/update"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::Reply do
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
    it "returns the reply notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Reply.to_s)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#subjects" do
    it "publishes to the owner's notifications subject" do
      expect(subject.subjects("alice")).to eq(["/actors/alice/notifications"])
    end
  end

  describe "#project" do
    let_create!(:object, named: parent, attributed_to: actor)
    let_create!(:object, named: reply, attributed_to: author, in_reply_to: parent)

    it "maps to the actor/reply key" do
      expect(subject.project(reply.iri)).to eq([{from_iri: actor.iri, to_iri: reply.iri}])
    end

    context "given a reply to a remote actor's post" do
      let_build(:actor, named: stranger, local: false)
      let_create!(:object, named: parent, attributed_to: stranger)

      it "maps to no key" do
        expect(subject.project(reply.iri)).to be_empty
      end
    end
  end

  describe "#membership" do
    context "given a reply to the actor's post" do
      let_create!(:object, named: parent, attributed_to: actor)
      let_create!(:object, named: reply, attributed_to: author, in_reply_to: parent)
      let_create!(:create, named: activity, actor: author, object: reply)

      it "does not select the reply" do
        expect(selected_iris).not_to contain(reply.iri)
      end

      context "in the actor's inbox" do
        before_each { put_in_inbox(actor, activity) }

        it "selects the reply" do
          expect(selected).to eq([{actor.iri, reply.iri, reply.created_at}])
        end

        context "whose delivering activity is undone" do
          before_each { activity.undo! }

          it "does not select the reply" do
            expect(selected_iris).not_to contain(reply.iri)
          end
        end

        context "but is attributed to the actor" do
          before_each { reply.assign(attributed_to: actor).save }

          it "does not select the reply" do
            expect(selected_iris).not_to contain(reply.iri)
          end
        end

        context "that also mentions the actor" do
          let_create!(:mention, named: nil, name: "actor@test.test", href: actor.iri, subject: reply)

          it "selects the reply" do
            expect(selected_iris).to contain(reply.iri)
          end
        end
      end

      context "in the actor's inbox" do
        let_create!(:announce, named: activity, actor: author, object: reply)

        before_each { put_in_inbox(actor, activity) }

        it "selects the reply" do
          expect(selected_iris).to contain(reply.iri)
        end
      end

      context "in the actor's inbox" do
        let_create!(:update, named: activity, actor: author, object: reply)

        before_each { put_in_inbox(actor, activity) }

        it "selects the reply" do
          expect(selected_iris).to contain(reply.iri)
        end
      end

      context "in the actor's outbox" do
        let_create!(:announce, named: activity, actor: actor, object: reply)

        before_each { put_in_outbox(actor, activity) }

        it "does not select the reply" do
          expect(selected_iris).not_to contain(reply.iri)
        end
      end
    end

    context "given a reply to another actor's post" do
      let_build(:actor, named: stranger, local: false)
      let_create!(:object, named: parent, attributed_to: stranger)
      let_create!(:object, named: reply, attributed_to: author, in_reply_to: parent)
      let_create!(:create, named: activity, actor: author, object: reply)

      before_each { put_in_inbox(actor, activity) }

      it "does not select the reply" do
        expect(selected_iris).not_to contain(reply.iri)
      end
    end

    context "when scoped" do
      let_create!(:object, named: parent, attributed_to: actor)
      let_create!(:object, named: reply, attributed_to: author, in_reply_to: parent)
      let_create!(:create, named: activity, actor: author, object: reply)

      before_each { put_in_inbox(actor, activity) }

      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: reply.iri}))
          .to eq([{actor.iri, reply.iri, reply.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: actor.iri, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the object IRI as a parameter, never interpolating it" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: reply.iri})
        expect(args).to eq([reply.iri])
      end
    end
  end
end
