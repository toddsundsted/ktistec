require "../../../src/rules/view/public_tagged"
require "../../../src/rules/maintainer"
require "../../../src/models/relationship/content/public_tagged"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/rule/view"

Spectator.describe Rules::View::PublicTagged do
  include ViewSpecHelper

  setup_spec

  let(actor) { register.actor }

  describe "registry" do
    it "is registered" do
      expect(Rules::View.registry).to contain(described_class.instance)
    end

    it "registers after PublicTimeline" do
      registry = Rules::View.registry
      expect(registry.index!(Rules::View::PublicTimeline.instance))
        .to be < registry.index!(described_class.instance)
    end
  end

  # within one `reconcile_object` pass `PublicTimeline` must create
  # the row before `PublicTagged` reads it, or a fresh tagged public
  # post is silently missed until its next tag change.

  describe "materializing a new tagged public post" do
    let_create!(:object, named: post, attributed_to: actor)
    let_create!(:create, named: activity, actor: actor, object: post)
    let_create!(:hashtag, name: "foo", subject: post)

    before_each { put_in_outbox(actor, activity) }

    it "materializes the row" do
      expect { Rules::Maintainer.reconcile_object(post.iri) }
        .to change { Relationship::Content::PublicTagged.count(to_iri: post.iri) }.from(0).to(1)
    end
  end

  describe "#type" do
    it "returns the public-tagged relationship type" do
      expect(subject.type).to eq(Relationship::Content::PublicTagged.to_s)
    end
  end

  describe "#repositions?" do
    it "does not reposition" do
      expect(subject.repositions?).to be_false
    end
  end

  describe "#subjects" do
    it "publishes nothing" do
      expect(subject.subjects("alice")).to be_empty
    end
  end

  let(foo_iri) { "#{Ktistec.host}/tags/foo" }

  describe "#project" do
    let_create!(:object, named: post)

    context "given a post with a hashtag" do
      let_create!(:hashtag, name: "foo", subject: post)

      it "maps it to its key" do
        expect(subject.project(post.iri)).to contain({from_iri: foo_iri, to_iri: post.iri})
      end
    end

    context "for a post with a hashtag that was removed" do
      let(gone_iri) { "#{Ktistec.host}/tags/gone" }
      let_create!(:public_tagged, from_iri: gone_iri, object: post)

      it "still maps it to its key" do
        expect(subject.project(post.iri)).to contain({from_iri: gone_iri, to_iri: post.iri})
      end
    end
  end

  describe "#membership" do
    let_create!(:object, named: post, attributed_to: actor)
    let_create!(:public_timeline, named: timeline, object: post)
    let_create!(:hashtag, name: "foo", subject: post)

    it "selects the post at its position in the public timeline" do
      expect(selected).to contain({foo_iri, post.iri, timeline.created_at})
    end

    context "when the post is not in the public timeline" do
      before_each { timeline.destroy }

      it "does not select the post" do
        expect(selected_iris).not_to contain(post.iri)
      end
    end

    context "wheb the post is not visible" do
      before_each { post.assign(visible: false).save }

      it "selects the post" do
        expect(selected_iris).to contain(post.iri)
      end
    end

    context "and the hashtag is mixed-case" do
      before_each { hashtag.assign(name: "Foo").save }

      it "emits a from_iri matching the lowercase partition" do
        from_iri, _, _ = selected.find! { |row| row[1] == post.iri }
        expect(from_iri).to eq(foo_iri)
      end
    end

    context "when scoped" do
      it "selects the full row for the key" do
        expect(selected({from_iri: foo_iri, to_iri: post.iri}))
          .to eq([{foo_iri, post.iri, timeline.created_at}])
      end

      it "selects nothing when the key does not qualify" do
        expect(selected_iris({from_iri: foo_iri, to_iri: "https://test.test/objects/absent"})).to be_empty
      end

      # intentional implementation test
      it "binds the key as parameters, never interpolating them" do
        _, args = subject.membership({from_iri: foo_iri, to_iri: post.iri})
        expect(args).to eq([post.iri, foo_iri])
      end
    end
  end
end
