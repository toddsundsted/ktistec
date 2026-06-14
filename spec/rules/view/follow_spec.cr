require "../../../src/rules/view/follow"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::Follow do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }
  let_build(:actor, named: follower)

  describe "registry" do
    it "is registered" do
      expect(Rules::View.registry).to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the follow notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Follow.to_s)
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
    let_create!(:follow, named: activity, actor: follower, object: actor)

    it "maps to the actor/activity key" do
      expect(subject.project(actor.iri)).to eq([{from_iri: actor.iri, to_iri: activity.iri}])
    end

    context "given a follow of a remote actor" do
      let_build(:actor, local: false)

      it "maps to no key" do
        expect(subject.project(actor.iri)).to be_empty
      end
    end
  end

  describe "#membership" do
    context "given a follow targeting the actor" do
      let_create!(:follow, named: activity, actor: follower, object: actor)

      it "does not select the follow" do
        expect(selected_iris).not_to contain(activity.iri)
      end

      context "in my inbox" do
        before_each { put_in_inbox(actor, activity) }

        it "selects the follow" do
          expect(selected).to eq([{actor.iri, activity.iri, activity.created_at}])
        end

        context "that is undone" do
          before_each { activity.undo! }

          it "does not select the follow" do
            expect(selected_iris).not_to contain(activity.iri)
          end
        end
      end
    end

    context "given a follow targeting another actor" do
      let_build(:actor, named: other)
      let_create!(:follow, named: activity, actor: actor, object: other)

      before_each { put_in_inbox(other, activity) }

      it "does not select the follow" do
        expect(selected_iris).not_to contain(activity.iri)
      end
    end

    context "when scoped" do
      let_create!(:follow, named: activity, actor: follower, object: actor)
      let_create!(:inbox_relationship, named: inbox, owner: actor, activity: activity)

      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: activity.iri}))
          .to eq([{actor.iri, activity.iri, activity.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: actor.iri, to_iri: "https://test.test/activities/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the activity IRI as a parameter, never interpolating it" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: activity.iri})
        expect(args).to eq([activity.iri])
      end
    end
  end
end
