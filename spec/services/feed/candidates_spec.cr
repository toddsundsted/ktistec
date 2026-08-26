require "../../../src/services/feed/candidates"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Candidates do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor)

  describe ".candidates_for" do
    let(cursor) { nil }
    let(limit) { nil }

    let(candidates) { Feed::Candidates.candidates_for(feed, cursor, limit) }

    it "returns no candidates" do
      expect(candidates).to be_empty
    end

    context "given an object" do
      let_create!(:object)

      it "returns the object as a candidate" do
        expect(candidates).to eq([object])
      end

      context "when the object has a verdict" do
        let_create!(:feed_verdict, feed: feed, object: object, included: false)

        it "does not return the object" do
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(1)
          expect(candidates).to be_empty
        end

        context "and the criteria change" do
          before_each { feed.assign(params: JSON.parse(%({"keywords": {"any": ["changed"]}})).as_h).save }

          it "returns the object" do
            expect(candidates).to eq([object])
          end
        end
      end

      # deletion and blocking are reversible, and neither goes through
      # `save`, so nothing would re-judge on reversal

      context "when the object is deleted" do
        before_each { object.delete! }

        pre_condition { expect(object.deleted?).to be_true }

        it "returns the object" do
          expect(candidates).to eq([object])
        end
      end

      context "when the object is blocked" do
        before_each { object.block! }

        pre_condition { expect(object.blocked?).to be_true }

        it "returns the object" do
          expect(candidates).to eq([object])
        end
      end

      context "when the object's author is deleted" do
        before_each { object.attributed_to.delete! }

        pre_condition { expect(object.attributed_to.deleted?).to be_true }

        it "returns the object" do
          expect(candidates).to eq([object])
        end
      end

      context "when the object's author is blocked" do
        before_each { object.attributed_to.block! }

        pre_condition { expect(object.attributed_to.blocked?).to be_true }

        it "returns the object" do
          expect(candidates).to eq([object])
        end
      end

      context "when the object is not published" do
        before_each { object.assign(published: nil).save }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object is special" do
        before_each { object.assign(special: "vote").save }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "when the object is not visible" do
        before_each { object.assign(visible: false).save }

        it "does not return the object" do
          expect(candidates).to be_empty
        end

        context "and a create is in the owner's inbox" do
          let_create(:create, object: object)

          before_each { put_in_inbox(actor, create) }

          it "returns the object" do
            expect(candidates).to eq([object])
          end

          context "but the activity is undone" do
            before_each { create.undo! }

            pre_condition { expect(create.undone?).to be_true }

            it "does not return the object" do
              expect(candidates).to be_empty
            end
          end
        end

        context "and a create is in the owner's outbox" do
          let_create(:create, object: object)

          before_each { put_in_outbox(actor, create) }

          it "returns the object" do
            expect(candidates).to eq([object])
          end
        end

        context "and a create is in another actor's inbox" do
          let(other) { register.actor }
          let_create(:create, object: object)

          before_each { put_in_inbox(other, create) }

          pre_condition { expect(Relationship::Content::Inbox.count(from_iri: actor.iri)).to eq(0) }

          it "does not return the object" do
            expect(candidates).to be_empty
          end
        end
      end

      context "when the feed's floor is at the object" do
        before_each { feed.assign(floor: object.created_at).save }

        it "does not return the object" do
          expect(candidates).to be_empty
        end
      end

      context "with more objects" do
        let_create!(:object, named: :object2)
        let_create!(:object, named: :object3)

        it "returns candidates newest first" do
          expect(candidates).to eq([object3, object2, object])
        end

        context "with a limit" do
          let(limit) { 2 }

          it "returns the newest candidates" do
            expect(candidates).to eq([object3, object2])
          end
        end

        context "with a cursor" do
          let(cursor) { object3.id }

          it "returns the candidates below the cursor" do
            expect(candidates).to eq([object2, object])
          end
        end

        context "when the feed's floor is at the middle object" do
          before_each { feed.assign(floor: object2.created_at).save }

          it "returns only the candidates above the floor" do
            expect(candidates).to eq([object3])
          end
        end
      end
    end

    it "raises an error" do
      expect { Feed::Candidates.candidates_for(feed, limit: 0) }.to raise_error(ArgumentError, "limit must be positive")
    end

    it "raises an error" do
      expect { Feed::Candidates.candidates_for(feed, limit: -1) }.to raise_error(ArgumentError, "limit must be positive")
    end
  end

  describe ".arrival_for" do
    let_create(:object, visible: true)

    subject { Feed::Candidates.arrival_for(feed, object) }

    it "returns the object's creation time" do
      expect(subject).to eq(object.created_at)
    end

    context "when the object is not visible" do
      before_each { object.assign(visible: false).save }

      it "returns nil" do
        expect(subject).to be_nil
      end

      context "and a create is in the owner's inbox" do
        let_create(:create, object: object)

        before_each { put_in_inbox(actor, create) }

        it "returns the object's creation time" do
          expect(subject).to eq(object.created_at)
        end

        context "but the activity is undone" do
          before_each { create.undo! }

          it "returns nil" do
            expect(subject).to be_nil
          end
        end

        context "but the feed's floor is above the object" do
          before_each { feed.assign(floor: object.created_at + 1.second).save }

          it "returns nil" do
            expect(subject).to be_nil
          end
        end
      end

      context "and a create is in the owner's outbox" do
        let_create(:create, object: object)

        before_each { put_in_outbox(actor, create) }

        it "returns the object's creation time" do
          expect(subject).to eq(object.created_at)
        end
      end

      context "and a create is in another actor's inbox" do
        let(other) { register.actor }
        let_create(:create, object: object)

        before_each { put_in_inbox(other, create) }

        pre_condition { expect(Relationship::Content::Inbox.count(from_iri: actor.iri)).to eq(0) }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "and a create is for another object" do
        let_create(:create)

        before_each { put_in_inbox(actor, create) }

        pre_condition { expect(Relationship::Content::Inbox.count(from_iri: actor.iri)).to eq(1) }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when the object is not published" do
      before_each { object.assign(published: nil).save }

      it "returns nil" do
        expect(subject).to be_nil
      end

      context "and a create is in the owner's outbox" do
        let_create(:create, object: object)

        before_each { put_in_outbox(actor, create) }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when the object is special" do
      before_each { object.assign(special: "vote").save }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    # deletion and blocking are reversible, and neither goes through
    # `save`, so nothing would re-judge on reversal

    context "when the object is deleted" do
      before_each { object.delete! }

      pre_condition { expect(object.deleted?).to be_true }

      it "is still a candidate" do
        expect(subject).to eq(object.created_at)
      end
    end

    context "when the object is blocked" do
      before_each { object.block! }

      pre_condition { expect(object.blocked?).to be_true }

      it "is still a candidate" do
        expect(subject).to eq(object.created_at)
      end
    end

    context "when the object's author is deleted" do
      before_each { object.attributed_to.delete! }

      pre_condition { expect(object.attributed_to.deleted?).to be_true }

      it "is still a candidate" do
        expect(subject).to eq(object.created_at)
      end
    end

    context "when the object's author is blocked" do
      before_each { object.attributed_to.block! }

      pre_condition { expect(object.attributed_to.blocked?).to be_true }

      it "is still a candidate" do
        expect(subject).to eq(object.created_at)
      end
    end

    context "when the feed has a floor below the object" do
      before_each { feed.assign(floor: object.created_at - 1.second).save }

      it "returns the object's creation time" do
        expect(subject).to eq(object.created_at)
      end

      context "and the floor is at the object" do
        before_each { feed.assign(floor: object.created_at).save }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "and the floor is above the object" do
        before_each { feed.assign(floor: object.created_at + 1.second).save }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end
    end
  end
end
