require "../../src/rules/maintainer"

require "../spec_helper/base"
require "../spec_helper/factory"

private class SyntheticView < Rules::View
  def type : String
    "Relationship::Content::SyntheticCollection"
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

private def materialized(view)
  Ktistec.database.query_all("SELECT to_iri FROM relationships WHERE type = ?", view.type, as: String).to_set
end

private def rows_for(view)
  Ktistec.database.query_all("SELECT id, to_iri, created_at FROM relationships WHERE type = ? ORDER BY id", view.type, as: {Int64, String, Time})
end

private def key_for(object)
  {from_iri: "owner", to_iri: object.iri}
end

Spectator.describe Rules::Maintainer do
  setup_spec

  let(view) { SyntheticView.new }

  describe ".reconcile" do
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

  describe ".reconcile_for" do
    let_create!(:object)

    it "inserts the key" do
      Rules::Maintainer.reconcile_for(view, key_for(object))
      expect(materialized(view)).to contain(object.iri)
    end

    context "when a key is already inserted" do
      before_each { Rules::Maintainer.reconcile_for(view, key_for(object)) }

      pre_condition { expect(materialized(view)).to contain(object.iri) }

      it "is does not insert a duplicate" do
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

  describe ".reconcile_object" do
    let_create!(:object)

    before_each { Rules::View.register(view) }
    after_each { Rules::View.registry.delete(view) }

    it "reconciles the registered view for the object" do
      Rules::Maintainer.reconcile_object(object.iri)
      expect(materialized(view)).to contain(object.iri)
    end
  end

  describe "scoped reconciliation equals batch" do
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
