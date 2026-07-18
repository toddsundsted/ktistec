require "../../../src/services/feed/window"
require "../../../src/services/feed/backend/criteria"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Feed::Window do
  setup_spec

  let(actor) { register.actor }

  let_create!(:feed, owner: actor, draft: true, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

  subject { described_class.new(feed) }

  def materialized
    Ktistec.database.query_all(
      "SELECT to_iri FROM relationships WHERE type = ?",
      feed.feed_type, as: String)
  end

  describe "#recompute" do
    it "judges nothing" do
      expect(subject.recompute).to eq(0)
    end

    context "given posts" do
      let_build(:object, named: hit, content: "<p>something alpha something</p>")
      let_build(:object, named: miss, content: "<p>something gamma something</p>")
      let_create(:create, named: hit_create, object: hit)
      let_create(:create, named: miss_create, object: miss)

      before_each do
        put_in_inbox(actor, hit_create)
        put_in_inbox(actor, miss_create)
      end

      it "judges the candidates" do
        expect(subject.recompute).to eq(2)
      end

      it "materializes the matching post" do
        subject.recompute
        expect(materialized).to eq([hit.iri])
      end

      it "exposes the matches as contents" do
        subject.recompute
        expect(subject.contents).to eq([hit])
      end

      context "and a computed window" do
        before_each { subject.recompute }

        it "judges nothing" do
          expect(subject.recompute).to eq(0)
        end

        context "and a new post" do
          let_build(:object, named: late, content: "<p>something alpha something</p>")
          let_create(:create, named: late_create, object: late)

          before_each { put_in_inbox(actor, late_create) }

          it "judges nothing" do
            expect(subject.recompute).to eq(0)
          end

          it "does not materialize the new post" do
            subject.recompute
            expect(materialized).to eq([hit.iri])
          end
        end

        context "when the criteria change" do
          before_each do
            feed.assign(params: JSON.parse(%({"keywords": {"any": ["gamma"]}})).as_h).save
          end

          it "judges the candidates" do
            expect(subject.recompute).to eq(2)
          end

          it "materializes the matching post" do
            subject.recompute
            expect(materialized).to eq([miss.iri])
          end
        end
      end
    end
  end
end
