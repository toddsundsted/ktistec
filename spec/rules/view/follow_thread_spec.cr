require "../../../src/rules/view/follow_thread"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::FollowThread do
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
    it "returns the thread-follow notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Follow::Thread.to_s)
    end
  end

  describe "#repositions?" do
    it "repositions" do
      expect(subject.repositions?).to be_true
    end
  end

  let(followed_at) { Time.utc(2026, 1, 1) }
  let(appeared_at) { followed_at + 1.hour }
  # the root predates the follow, so it satisfies the root-existence
  # requirement without itself contributing to the position.
  let_create!(:object, named: root, attributed_to: author, created_at: followed_at - 1.hour)

  describe "#project" do
    let_create!(:object, named: post, attributed_to: author, in_reply_to: root, created_at: appeared_at)

    context "with no followed thread" do
      it "maps to no key" do
        expect(subject.project(post.iri)).to be_empty
      end
    end

    context "in a thread the owner follows" do
      let_create!(:follow_thread_relationship, named: nil, actor: actor, thread: root.iri)

      it "maps to the owner/thread key" do
        expect(subject.project(post.iri)).to eq([{from_iri: actor.iri, to_iri: root.iri}])
      end

      context "and the object is a deep reply" do
        let_create!(:object, named: deep, attributed_to: author, in_reply_to: post, created_at: appeared_at + 1.hour)

        it "maps to the owner/thread key" do
          expect(subject.project(deep.iri)).to eq([{from_iri: actor.iri, to_iri: root.iri}])
        end
      end
    end
  end

  describe "#membership" do
    let_create!(:follow_thread_relationship, named: nil, actor: actor, thread: root.iri, created_at: followed_at)
    let_create!(:object, named: post, attributed_to: author, in_reply_to: root, created_at: appeared_at)

    context "given a reply that appeared after the follow" do
      it "uses the appearance time as the membership timestamp" do
        expect(selected).to eq([{actor.iri, root.iri, post.created_at}])
      end

      context "from a blocked sender" do
        before_each { author.block! }

        it "does not select the thread" do
          expect(selected).to be_empty
        end
      end

      context "attributed to the owner" do
        before_each { post.assign(attributed_to: actor).save }

        it "does not select the thread" do
          expect(selected).to be_empty
        end
      end

      context "of a deleted object" do
        before_each { post.delete! }

        it "selects the thread" do
          expect(selected).to eq([{actor.iri, root.iri, post.created_at}])
        end
      end

      context "and a second reply that appeared after the first" do
        let_build(:actor, named: other)
        let_create!(:object, named: newer, attributed_to: other, in_reply_to: root, created_at: appeared_at + 1.hour)

        it "uses the newer appearance time as the membership timestamp" do
          expect(selected).to eq([{actor.iri, root.iri, newer.created_at}])
        end

        context "from a blocked sender" do
          before_each { other.block! }

          it "uses the earlier appearance time as the membership timestamp" do
            expect(selected).to eq([{actor.iri, root.iri, post.created_at}])
          end
        end
      end
    end

    context "given a reply that appeared before the follow" do
      let(appeared_at) { followed_at - 1.hour }

      it "does not select the thread" do
        expect(selected).to be_empty
      end
    end

    context "when the thread root is not cached" do
      let(uncached_iri) { "https://remote/uncached" }
      let_create!(:follow_thread_relationship, named: extra, actor: actor, thread: uncached_iri, created_at: followed_at)
      let_create!(:object, named: orphan, attributed_to: author, in_reply_to_iri: uncached_iri, created_at: appeared_at)

      pre_condition { expect(orphan.thread).to eq(uncached_iri) }

      it "does not select the thread" do
        expect(selected({from_iri: actor.iri, to_iri: uncached_iri})).to be_empty
      end
    end

    context "when scoped" do
      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: root.iri}))
          .to eq([{actor.iri, root.iri, post.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected({from_iri: actor.iri, to_iri: "https://remote/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the owner and thread as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: root.iri})
        expect(args).to eq([actor.iri, root.iri])
      end
    end
  end
end
