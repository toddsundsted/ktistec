require "../../../src/rules/view/public_timeline"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::PublicTimeline do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }

  PUBLIC = Ktistec::Constants::PUBLIC

  describe "registry" do
    it "is registered" do
      expect(Rules::View.registry).to contain(described_class.instance)
    end
  end

  describe "#type" do
    it "returns the public timeline relationship type" do
      expect(subject.type).to eq(Relationship::Content::PublicTimeline.to_s)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#subjects" do
    it "publishes nothing (the public timeline has no real-time push)" do
      expect(subject.subjects("alice")).to be_empty
    end
  end

  describe "#project" do
    it "maps an object to its public-timeline key" do
      expect(subject.project("https://test.test/objects/foo"))
        .to eq([{from_iri: PUBLIC, to_iri: "https://test.test/objects/foo"}])
    end
  end

  describe "#membership" do
    context "given a locally created post" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:create, named: activity, actor: actor, object: post)

      before_each { put_in_outbox(actor, activity) }

      it "selects the post" do
        expect(selected_iris).to contain(post.iri)
      end
    end

    context "given a locally announced post" do
      let_build(:object, named: post)
      let_build(:announce, named: activity, actor: actor, object: post)

      before_each { put_in_outbox(actor, activity) }

      it "selects the post" do
        expect(selected_iris).to contain(post.iri)
      end
    end

    context "given a reply" do
      let_build(:object, named: parent, attributed_to: actor)
      let_build(:object, named: reply, attributed_to: actor, in_reply_to_iri: parent.iri)
      let_build(:create, named: reply_activity, actor: actor, object: reply)

      before_each { put_in_outbox(actor, reply_activity) }

      it "does not select the reply" do
        expect(selected_iris).not_to contain(reply.iri)
      end
    end

    context "given a remote post" do
      let_build(:actor, named: remote)
      let_build(:object, named: post, attributed_to: remote)
      let_build(:create, named: activity, actor: remote, object: post)

      before_each { put_in_outbox(remote, activity) }

      it "does not select the post" do
        expect(selected_iris).not_to contain(post.iri)
      end
    end

    context "given a post whose sole activity is undone" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:create, named: activity, actor: actor, object: post)

      before_each do
        put_in_outbox(actor, activity)
        activity.undo!
      end

      it "does not select the post" do
        expect(selected_iris).not_to contain(post.iri)
      end
    end

    context "given a deleted post" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:create, named: activity, actor: actor, object: post)

      before_each do
        put_in_outbox(actor, activity)
        post.delete!
      end

      it "because deleted is a render filter, not membership" do
        expect(selected_iris).to contain(post.iri)
      end
    end

    context "given a post with two contributions" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:create, named: earlier, actor: actor, object: post)
      let_create!(:outbox_relationship, named: earlier_outbox, owner: actor, activity: earlier)
      let_build(:announce, named: later, actor: actor, object: post)
      let_create!(:outbox_relationship, named: later_outbox, owner: actor, activity: later)

      it "selects the earlier contribution" do
        expect(selected).to eq([{PUBLIC, post.iri, earlier_outbox.created_at}])
      end
    end

    context "when scoped" do
      let_build(:object, named: post, attributed_to: actor)
      let_build(:create, named: activity, actor: actor, object: post)
      let_create!(:outbox_relationship, named: outbox, owner: actor, activity: activity)

      it "selects the full row for the key" do
        expect(selected({from_iri: PUBLIC, to_iri: post.iri}))
          .to eq([{PUBLIC, post.iri, outbox.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: PUBLIC, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the object IRI as a parameter, never interpolating it" do
        _, args = subject.membership({from_iri: PUBLIC, to_iri: post.iri})
        expect(args).to eq([post.iri])
      end
    end
  end
end
