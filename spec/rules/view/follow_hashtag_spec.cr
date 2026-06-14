require "../../../src/rules/view/follow_hashtag"
require "../../../src/models/relationship/content/notification/follow/hashtag"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::FollowHashtag do
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
    it "returns the hashtag-follow notification relationship type" do
      expect(subject.type).to eq(Relationship::Content::Notification::Follow::Hashtag.to_s)
    end
  end

  describe "#repositions?" do
    it "repositions" do
      expect(subject.repositions?).to be_true
    end
  end

  let(tag_name) { "crystal" }
  let(followed_at) { Time.utc(2026, 1, 1) }
  let(appeared_at) { followed_at + 1.hour }
  let_build(:object, named: post, attributed_to: author, created_at: appeared_at)

  describe "#subjects" do
    it "publishes to the owner's notifications subject" do
      expect(subject.subjects("alice")).to eq(["/actors/alice/notifications"])
    end
  end

  describe "#project" do
    let_create!(:hashtag, named: nil, name: tag_name, subject: post)

    context "with no followed hashtag" do
      it "maps to no key" do
        expect(subject.project(post.iri)).to be_empty
      end
    end

    context "tagged with a hashtag the owner follows" do
      let_create!(:follow_hashtag_relationship, named: nil, actor: actor, name: "crystal")

      it "maps to the owner/name key" do
        expect(subject.project(post.iri)).to eq([{from_iri: actor.iri, to_iri: "crystal"}])
      end

      context "in a different case" do
        let(tag_name) { super.upcase }

        it "maps to the owner/name key" do
          expect(subject.project(post.iri)).to eq([{from_iri: actor.iri, to_iri: "crystal"}])
        end
      end

      context "and another hashtag the owner follows" do
        let_create!(:hashtag, named: nil, name: "ruby", subject: post)
        let_create!(:follow_hashtag_relationship, named: nil, actor: actor, name: "ruby")

        it "maps to a key per followed hashtag" do
          expect(subject.project(post.iri)).to contain_exactly(
            {from_iri: actor.iri, to_iri: "crystal"},
            {from_iri: actor.iri, to_iri: "ruby"},
          )
        end
      end
    end
  end

  describe "#membership" do
    let_create!(:hashtag, named: nil, name: tag_name, subject: post)
    let_create!(:follow_hashtag_relationship, named: nil, actor: actor, name: "crystal", created_at: followed_at)

    context "given a post that appeared after the follow" do
      it "uses the appearance time as the membership timestamp" do
        expect(selected).to eq([{actor.iri, "crystal", post.created_at}])
      end

      context "in a different case" do
        let(tag_name) { super.upcase }

        it "selects the hashtag" do
          expect(selected).to eq([{actor.iri, "crystal", post.created_at}])
        end
      end

      context "from a blocked sender" do
        before_each { author.block! }

        it "does not select the hashtag" do
          expect(selected).to be_empty
        end
      end

      context "attributed to the owner" do
        before_each { post.assign(attributed_to: actor).save }

        it "does not select the hashtag" do
          expect(selected).to be_empty
        end
      end

      context "of a deleted object" do
        before_each { post.delete! }

        it "selects the hashtag" do
          expect(selected).to eq([{actor.iri, "crystal", post.created_at}])
        end
      end

      context "and a second post that appeared after the first" do
        let_build(:actor, named: other)
        let_build(:object, named: newer, attributed_to: other, created_at: appeared_at + 1.hour)
        let_create!(:hashtag, named: nil, name: "crystal", subject: newer)

        it "uses the newer appearance time as the membership timestamp" do
          expect(selected).to eq([{actor.iri, "crystal", newer.created_at}])
        end

        context "from a blocked sender" do
          before_each { other.block! }

          it "uses the earlier appearance time as the membership timestamp" do
            expect(selected).to eq([{actor.iri, "crystal", post.created_at}])
          end
        end
      end
    end

    context "given a post that appeared before the follow" do
      let(appeared_at) { followed_at - 1.hour }

      it "does not select the hashtag" do
        expect(selected).to be_empty
      end
    end

    context "when scoped" do
      it "selects the full row for the key" do
        expect(selected({from_iri: actor.iri, to_iri: "crystal"}))
          .to eq([{actor.iri, "crystal", post.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected({from_iri: actor.iri, to_iri: "absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the owner and name as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: actor.iri, to_iri: "crystal"})
        expect(args).to eq([actor.iri, "crystal"])
      end
    end
  end
end
