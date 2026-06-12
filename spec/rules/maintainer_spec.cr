require "../../src/rules/maintainer"

require "../spec_helper/base"
require "../spec_helper/factory"

# An identity-keyed view.
#
# The stored row's `(from_iri, to_iri)` is the membership key (one row
# per object).
#
private class SyntheticIdentityKeyedView < Rules::View
  def type : String
    "Relationship::Content::SyntheticIdentity"
  end

  def membership(key : Rules::View::Key? = nil) : {String, Array(DB::Any)}
    if key
      scope = "AND iri = ?"
      args = Array(DB::Any){key[:to_iri]}
    else
      scope = ""
      args = Array(DB::Any).new
    end
    query = <<-SQL
      SELECT 'owner' AS from_iri, iri AS to_iri, created_at AS position
        FROM objects
       WHERE visible = 1
       #{scope}
    SQL
    {query, args}
  end

  def project(object_iri : String) : Array(Rules::View::Key)
    [{from_iri: "owner", to_iri: object_iri}]
  end
end

# A representative-keyed view.
#
# One stored row per group (an object's `attributed_to_iri`), keyed on
# a member that changes -- the latest visible object in the group.
#
private class SyntheticRepresentativeKeyedView < Rules::View
  def type : String
    "Relationship::Content::SyntheticRepresentative"
  end

  def membership(key : Rules::View::Key? = nil) : {String, Array(DB::Any)}
    if key
      scope = "AND o.attributed_to_iri = ?"
      args = Array(DB::Any){key[:to_iri]}
    else
      scope = ""
      args = Array(DB::Any).new
    end
    query = <<-SQL
      SELECT 'owner' AS from_iri, o.iri AS to_iri, o.created_at AS position
        FROM objects o
       WHERE o.visible = 1
         AND NOT EXISTS (
           SELECT 1 FROM objects o2
            WHERE o2.attributed_to_iri = o.attributed_to_iri
              AND o2.visible = 1
              AND o2.created_at > o.created_at
         )
         #{scope}
    SQL
    {query, args}
  end

  def project(object_iri : String) : Array(Rules::View::Key)
    group = Ktistec.database.query_one?("SELECT attributed_to_iri FROM objects WHERE iri = ?", object_iri, as: String)
    group ? [{from_iri: "owner", to_iri: group}] : [] of Rules::View::Key
  end

  def stored_scope(key : Rules::View::Key) : {String, Array(DB::Any)}
    {"from_iri = ? AND to_iri IN (SELECT iri FROM objects WHERE attributed_to_iri = ?)", Array(DB::Any){key[:from_iri], key[:to_iri]}}
  end
end

# A stable-keyed recency view.
#
# One stored row per group (an object's `attributed_to_iri`). The
# stored key never changes but the position changes to the group's
# latest visible object.
#
private class SyntheticStableKeyedView < Rules::View
  def type : String
    "Relationship::Content::SyntheticStable"
  end

  def repositions? : Bool
    true
  end

  def membership(key : Rules::View::Key? = nil) : {String, Array(DB::Any)}
    if key
      scope = "AND o.attributed_to_iri = ?"
      args = Array(DB::Any){key[:to_iri]}
    else
      scope = ""
      args = Array(DB::Any).new
    end
    query = <<-SQL
      SELECT 'owner' AS from_iri, o.attributed_to_iri AS to_iri, MAX(o.created_at) AS position
        FROM objects o
       WHERE o.visible = 1
       #{scope}
       GROUP BY o.attributed_to_iri
    SQL
    {query, args}
  end

  def project(object_iri : String) : Array(Rules::View::Key)
    group = Ktistec.database.query_one?("SELECT attributed_to_iri FROM objects WHERE iri = ?", object_iri, as: String)
    group ? [{from_iri: "owner", to_iri: group}] : [] of Rules::View::Key
  end
end

private def materialized(view)
  Ktistec.database.query_all("SELECT to_iri FROM relationships WHERE type = ?", view.type, as: String).to_set
end

private def rows_for(view)
  Ktistec.database.query_all("SELECT id, to_iri, created_at FROM relationships WHERE type = ? ORDER BY id", view.type, as: {Int64, String, Time})
end

private def key_for(object)
  {from_iri: "owner", to_iri: object.iri}
end

private GROUP = "https://test.test/actors/grouped"

private def group_key
  {from_iri: "owner", to_iri: GROUP}
end

Spectator.describe Rules::Maintainer do
  setup_spec

  describe ".reconcile" do
    context "an identity-keyed view" do
      let(view) { SyntheticIdentityKeyedView.new }

      context "given a stored member the query no longer selects" do
        let_create!(:object)

        before_each do
          Rules::Maintainer.reconcile(view)
          object.assign(visible: false).save
        end

        pre_condition { expect(materialized(view)).to contain(object.iri) }

        it "is deleted" do
          Rules::Maintainer.reconcile(view)
          expect(materialized(view)).not_to contain(object.iri)
        end
      end

      context "given a missed older member" do
        let_create!(:object, named: older, created_at: Time.utc - 2.hours)
        let_create!(:object, named: newer, created_at: Time.utc - 1.minute)

        before_each { Rules::Maintainer.reconcile_for(view, key_for(newer)) }

        it "positions the older member correctly" do
          Rules::Maintainer.reconcile(view)
          rows = rows_for(view)
          older_row = rows.find! { |(_, to_iri, _)| to_iri == older.iri }
          newer_row = rows.find! { |(_, to_iri, _)| to_iri == newer.iri }
          # it is assigned a newer/higher id...
          expect(older_row[0]).to be_gt(newer_row[0])
          # ...but it preserves the created_at ordering
          expect(older_row[2]).to be_lt(newer_row[2])
        end
      end
    end

    context "a representative-keyed view" do
      let(view) { SyntheticRepresentativeKeyedView.new }

      let_create!(:object, named: first, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 2.hours)
      let_create!(:object, named: second, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 1.minute)
      let_create(:object, named: third, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc)

      context "given an older member" do
        before_each { Rules::Maintainer.reconcile(view) }

        pre_condition { expect(materialized(view)).to eq(Set{second.iri}) }

        it "swaps to the newer member" do
          third.save
          Rules::Maintainer.reconcile(view)
          # one physical row per group
          rows = rows_for(view)
          expect(rows.size).to eq(1)
          expect(rows.first[1]).to eq(third.iri)
        end
      end
    end
  end

  describe ".reconcile_for" do
    context "an identity-keyed view" do
      let(view) { SyntheticIdentityKeyedView.new }

      let_create!(:object)

      it "inserts the key" do
        Rules::Maintainer.reconcile_for(view, key_for(object))
        expect(materialized(view)).to contain(object.iri)
      end

      context "when a key is already inserted" do
        before_each { Rules::Maintainer.reconcile_for(view, key_for(object)) }

        pre_condition { expect(materialized(view)).to contain(object.iri) }

        it "does not insert a duplicate" do
          expect { Rules::Maintainer.reconcile_for(view, key_for(object)) }
            .not_to change { materialized(view).size }
        end

        context "but no longer qualifies" do
          before_each { object.assign(visible: false).save }

          it "is deleted" do
            Rules::Maintainer.reconcile_for(view, key_for(object))
            expect(materialized(view)).not_to contain(object.iri)
          end
        end
      end
    end

    context "a representative-keyed view" do
      let(view) { SyntheticRepresentativeKeyedView.new }

      let_create!(:object, named: first, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 2.hours)
      let_create!(:object, named: second, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 1.minute)
      let_create(:object, named: third, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc)

      it "stores the latest member" do
        Rules::Maintainer.reconcile_for(view, group_key)
        expect(materialized(view)).to eq(Set{second.iri})
      end

      context "given a stored member" do
        before_each { Rules::Maintainer.reconcile_for(view, group_key) }

        pre_condition { expect(materialized(view)).to eq(Set{second.iri}) }

        it "swaps to a newer member" do
          third.save
          Rules::Maintainer.reconcile_for(view, group_key)
          # one physical row per group
          rows = rows_for(view)
          expect(rows.size).to eq(1)
          expect(rows.first[1]).to eq(third.iri)
          expect(rows.first[2]).to be_close(third.created_at, 1.second)
        end

        it "falls back to the previous member" do
          second.assign(visible: false).save
          Rules::Maintainer.reconcile_for(view, group_key)
          expect(materialized(view)).to eq(Set{first.iri})
        end

        it "evicts the group entirely" do
          first.assign(visible: false).save
          second.assign(visible: false).save
          Rules::Maintainer.reconcile_for(view, group_key)
          expect(materialized(view)).to be_empty
        end
      end
    end

    context "a stable-keyed recency view" do
      let(view) { SyntheticStableKeyedView.new }

      let_create!(:object, named: first, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 2.hours)
      let_create!(:object, named: second, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 1.minute)
      let_create(:object, named: third, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc)

      it "stores the member at the latest position" do
        Rules::Maintainer.reconcile_for(view, group_key)
        expect(rows_for(view).first[2]).to be_close(second.created_at, 1.second)
      end

      context "given a stored member" do
        before_each { Rules::Maintainer.reconcile_for(view, group_key) }

        pre_condition { expect(rows_for(view).first[2]).to be_close(second.created_at, 1.second) }

        it "updates the position when newer support arrives" do
          third.save
          Rules::Maintainer.reconcile_for(view, group_key)
          expect(rows_for(view).first[2]).to be_close(third.created_at, 1.second)
        end

        it "keeps one row at the stable key" do
          third.save
          Rules::Maintainer.reconcile_for(view, group_key)
          rows = rows_for(view)
          expect(rows.size).to eq(1)
          expect(rows.first[1]).to eq(GROUP)
        end
      end
    end
  end

  describe ".reconcile_object" do
    context "an identity-keyed view" do
      let(view) { SyntheticIdentityKeyedView.new }

      let_create!(:object)

      before_each { Rules::View.register(view) }
      after_each { Rules::View.registry.delete(view) }

      it "projects the object to itself" do
        Rules::Maintainer.reconcile_object(object.iri)
        expect(materialized(view)).to contain(object.iri)
      end
    end

    context "a representative-keyed view" do
      let(view) { SyntheticRepresentativeKeyedView.new }

      let_create!(:object, named: first, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 2.hours)
      let_create!(:object, named: second, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 1.minute)

      before_each { Rules::View.register(view) }
      after_each { Rules::View.registry.delete(view) }

      it "projects a member to its group's representative" do
        Rules::Maintainer.reconcile_object(first.iri)
        expect(materialized(view)).to eq(Set{second.iri})
      end
    end
  end

  describe "change reporting" do
    let(view) { SyntheticIdentityKeyedView.new }

    let_create!(:object)

    it "reports a change when a key is inserted" do
      expect(Rules::Maintainer.reconcile_for(view, key_for(object))).to be_true
    end

    context "given an inserted key" do
      before_each { Rules::Maintainer.reconcile_for(view, key_for(object)) }

      pre_condition { expect(materialized(view)).to contain(object.iri) }

      it "reports no change" do
        expect(Rules::Maintainer.reconcile_for(view, key_for(object))).to be_false
      end
    end

    context "given a registered view" do
      before_each { Rules::View.register(view) }
      after_each { Rules::View.registry.delete(view) }

      it "returns the changed pairs" do
        expect(Rules::Maintainer.reconcile_object(object.iri)).to eq([{view, "owner"}])
      end

      context "given an inserted key" do
        before_each { Rules::Maintainer.reconcile_object(object.iri) }

        pre_condition { expect(materialized(view)).to contain(object.iri) }

        it "returns no pairs" do
          expect(Rules::Maintainer.reconcile_object(object.iri)).to be_empty
        end
      end
    end
  end

  describe "scoped reconcile converges to batch reconcile" do
    context "an identity-keyed view" do
      let(view) { SyntheticIdentityKeyedView.new }

      let_create!(:object, named: member1, visible: true)
      let_create!(:object, named: member2, visible: true)
      let_create!(:object, named: member3, visible: false)

      it "produces the same membership" do
        Rules::Maintainer.reconcile(view)
        batch = materialized(view)

        Ktistec.database.exec("DELETE FROM relationships WHERE type = ?", view.type)

        [member1, member2, member3].each do |object|
          Rules::Maintainer.reconcile_for(view, key_for(object))
        end
        scoped = materialized(view)

        expect(scoped).to eq(batch)
      end
    end

    context "a representative-keyed view" do
      let(view) { SyntheticRepresentativeKeyedView.new }

      let_create!(:object, named: first, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 2.hours)
      let_create!(:object, named: second, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 1.minute)

      it "produces the same membership" do
        Rules::Maintainer.reconcile(view)
        batch = materialized(view)

        Ktistec.database.exec("DELETE FROM relationships WHERE type = ?", view.type)

        Rules::Maintainer.reconcile_for(view, group_key)
        scoped = materialized(view)

        expect(scoped).to eq(batch)
        expect(scoped).to eq(Set{second.iri})
      end
    end

    context "a stable-keyed recency view" do
      let(view) { SyntheticStableKeyedView.new }

      let_create!(:object, named: first, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 2.hours)
      let_create!(:object, named: second, attributed_to: nil, attributed_to_iri: GROUP, created_at: Time.utc - 1.minute)

      it "produces the same position" do
        Rules::Maintainer.reconcile(view)
        batch = rows_for(view).map { |(_, to_iri, position)| {to_iri, position} }

        Ktistec.database.exec("DELETE FROM relationships WHERE type = ?", view.type)

        second.assign(visible: false).save
        Rules::Maintainer.reconcile_for(view, group_key)
        second.assign(visible: true).save
        Rules::Maintainer.reconcile_for(view, group_key)
        scoped = rows_for(view).map { |(_, to_iri, position)| {to_iri, position} }

        expect(scoped).to eq(batch)
      end
    end
  end

  describe ".bucket" do
    it "classifies a registered view as :registry" do
      expect(Rules::Maintainer.bucket(Relationship::Content::PublicTimeline.to_s)).to eq(:registry)
    end

    it "classifies a quote notification as :imperative" do
      expect(Rules::Maintainer.bucket(Relationship::Content::Notification::Quote.to_s)).to eq(:imperative)
    end

    it "classifies a poll-expiry notification as :imperative" do
      expect(Rules::Maintainer.bucket(Relationship::Content::Notification::Poll::Expiry.to_s)).to eq(:imperative)
    end

    it "classifies an unowned type as :error" do
      expect(Rules::Maintainer.bucket(Relationship::Content::Timeline.to_s)).to eq(:error)
    end
  end
end
