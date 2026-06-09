require "../../../src/rules/view/follow_mention"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::FollowMention do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }
  let_build(:actor, named: author)

  describe "registry" do
    it "is not registered" do
      expect(Rules::View.registry).not_to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the mention-follow notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Follow::Mention.to_s)
    end
  end

  describe "#repositions?" do
    it "repositions" do
      expect(subject.repositions?).to be_true
    end
  end

  let(mention_name) { "alice@remote" }
  let(mention_href) { "https://remote/actors/alice" }
  let(followed_at) { Time.utc(2026, 1, 1) }
  let(appeared_at) { followed_at + 1.hour }
  let_build(:object, named: post, attributed_to: author, created_at: appeared_at)

  describe "#project" do
    let_create!(:mention, named: nil, name: mention_name, href: mention_href, subject: post)

    context "with no followed mention" do
      it "maps to no key" do
        expect(subject.project(post.iri)).to be_empty
      end
    end

    context "mentioning an actor the owner follows" do
      let_create!(:follow_mention_relationship, named: nil, actor: actor, href: mention_href)

      it "maps to the owner/href key" do
        expect(subject.project(post.iri)).to eq([{from_iri: actor.iri, to_iri: mention_href}])
      end

      context "and another actor the owner follows" do
        let(other_href) { "https://remote/actors/bob" }
        let_create!(:mention, named: nil, name: "bob@remote", href: other_href, subject: post)
        let_create!(:follow_mention_relationship, named: nil, actor: actor, href: other_href)

        it "maps to a key per followed mention" do
          expect(subject.project(post.iri)).to contain_exactly(
            {from_iri: actor.iri, to_iri: mention_href},
            {from_iri: actor.iri, to_iri: other_href},
          )
        end
      end
    end
  end

  describe "#membership" do
    let_create!(:mention, named: nil, name: mention_name, href: mention_href, subject: post)
    let_create!(:follow_mention_relationship, named: nil, actor: actor, href: mention_href, created_at: followed_at)

    context "given a post that appeared after the follow" do
      it "uses the appearance time as the membership timestamp" do
        expect(selected).to eq([{actor.iri, mention_href, post.created_at}])
      end

      context "from a blocked sender" do
        before_each { author.block! }

        it "does not select the mention" do
          expect(selected).to be_empty
        end
      end

      context "attributed to the owner" do
        before_each { post.assign(attributed_to: actor).save }

        it "does not select the mention" do
          expect(selected).to be_empty
        end
      end

      context "of a deleted object" do
        before_each { post.delete! }

        it "selects the mention" do
          expect(selected).to eq([{actor.iri, mention_href, post.created_at}])
        end
      end

      context "and a second post that appeared after the first" do
        let_build(:actor, named: other)
        let_build(:object, named: newer, attributed_to: other, created_at: appeared_at + 1.hour)
        let_create!(:mention, named: nil, name: mention_name, href: mention_href, subject: newer)

        it "uses the newer appearance time as the membership timestamp" do
          expect(selected).to eq([{actor.iri, mention_href, newer.created_at}])
        end

        context "from a blocked sender" do
          before_each { other.block! }

          it "uses the earlier appearance time as the membership timestamp" do
            expect(selected).to eq([{actor.iri, mention_href, post.created_at}])
          end
        end
      end
    end

    context "given a post that appeared before the follow" do
      let(appeared_at) { followed_at - 1.hour }

      it "does not select the mention" do
        expect(selected).to be_empty
      end
    end

    context "when scoped" do
      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: mention_href}))
          .to eq([{actor.iri, mention_href, post.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected({from_iri: actor.iri, to_iri: "https://remote/actors/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the owner and href as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: mention_href})
        expect(args).to eq([actor.iri, mention_href])
      end
    end
  end
end
