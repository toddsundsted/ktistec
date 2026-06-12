require "../../../src/rules/view/dislike"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::Dislike do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }
  let_build(:actor, named: disliker)

  describe "registry" do
    it "is registered" do
      expect(Rules::View.registry).to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the dislike notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Dislike.to_s)
    end
  end

  describe "#repositions?" do
    it "repositions" do
      expect(subject.repositions?).to be_true
    end
  end

  describe "#subjects" do
    it "publishes to the owner's notifications subject" do
      expect(subject.subjects("alice")).to eq(["/actors/alice/notifications"])
    end
  end

  describe "#project" do
    context "given a local object" do
      let_create!(:object, named: post, attributed_to: actor)

      it "maps to the owner/object key" do
        expect(subject.project(post.iri)).to eq([{from_iri: actor.iri, to_iri: post.iri}])
      end
    end

    context "given a remote object" do
      let_create!(:object, named: post)

      it "maps to no key" do
        expect(subject.project(post.iri)).to be_empty
      end
    end
  end

  describe "#membership" do
    context "given a dislike" do
      let_build(:object, named: post, attributed_to: actor)
      let_create!(:dislike, named: activity, actor: disliker, object: post)

      it "does not select the dislike" do
        expect(selected_iris).not_to contain(activity.iri)
      end

      context "in my inbox" do
        before_each { put_in_inbox(actor, activity) }

        it "selects the dislike" do
          expect(selected).to eq([{actor.iri, activity.iri, activity.created_at}])
        end

        context "that is undone" do
          before_each { activity.undo! }

          it "does not select the dislike" do
            expect(selected_iris).not_to contain(activity.iri)
          end
        end

        context "from a blocked sender" do
          before_each { disliker.block! }

          it "does not select the dislike" do
            expect(selected_iris).not_to contain(activity.iri)
          end
        end

        context "of a deleted object" do
          before_each { post.delete! }

          it "still selects the dislike (deleted is a render filter, not membership)" do
            expect(selected_iris).to contain(activity.iri)
          end
        end

        context "disliked by me" do
          before_each { activity.assign(actor: actor).save }

          it "does not select the dislike" do
            expect(selected_iris).not_to contain(activity.iri)
          end
        end
      end
    end

    context "given a dislike of a remote owner's object" do
      let_build(:actor, named: remote)
      let_build(:object, named: post, attributed_to: remote)
      let_build(:dislike, named: activity, actor: disliker, object: post)

      before_each { put_in_inbox(remote, activity) }

      it "does not select the dislike" do
        expect(selected_iris).not_to contain(activity.iri)
      end
    end

    context "given two dislikes" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:actor, named: other)
      let_build(:dislike, named: earlier, actor: disliker, object: post)
      let_build(:dislike, named: later, actor: other, object: post)

      before_each do
        put_in_inbox(actor, earlier)
        put_in_inbox(actor, later)
      end

      it "selects the latest dislike" do
        expect(selected).to eq([{actor.iri, later.iri, later.created_at}])
      end

      context "and the latest dislike is undone" do
        before_each { later.undo! }

        it "falls back to the earlier dislike" do
          expect(selected).to eq([{actor.iri, earlier.iri, earlier.created_at}])
        end
      end

      context "and the latest dislike's sender is blocked" do
        before_each { other.block! }

        it "falls back to the earlier dislike" do
          expect(selected).to eq([{actor.iri, earlier.iri, earlier.created_at}])
        end
      end
    end

    context "when scoped" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:dislike, named: activity, actor: disliker, object: post)
      let_create!(:inbox_relationship, named: inbox, owner: actor, activity: activity)

      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: post.iri}))
          .to eq([{actor.iri, activity.iri, activity.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: actor.iri, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the object IRI as a parameter, never interpolating it" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: post.iri})
        expect(args).to eq([post.iri])
      end
    end
  end

  describe "#stored_scope" do
    let_build(:object, named: post, attributed_to: actor)
    let_build(:object, named: other, attributed_to: actor)
    let_build(:dislike, named: post_dislike, actor: disliker, object: post)
    let_build(:dislike, named: other_dislike, actor: disliker, object: other)
    let_create!(:notification_dislike, named: nil, owner: actor, activity: post_dislike)
    let_create!(:notification_dislike, named: nil, owner: actor, activity: other_dislike)

    let(key) { {from_iri: actor.iri, to_iri: post.iri} }

    it "matches the stored rows whose dislike is of the key's object" do
      expect(scoped_rows(key)).to eq(Set{post_dislike.iri})
    end

    # intentional implementation test
    it "binds the object IRI as a parameter, never interpolating it" do
      predicate, args = subject.stored_scope(key)
      expect(predicate).not_to contain(post.iri)
      expect(args).to contain(post.iri)
    end
  end
end
