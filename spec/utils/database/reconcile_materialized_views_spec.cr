require "../../../src/utils/database/reconcile_materialized_views"
require "../../../src/models/activity_pub/activity/like"
require "../../../src/models/activity_pub/activity/create"
require "../../../src/models/activity_pub/activity/quote_request"
require "../../../src/models/relationship/content/notification/like"
require "../../../src/models/relationship/content/notification/quote"
require "../../../src/models/relationship/content/timeline/create"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Ktistec::Database::ReconcileMaterializedViews do
  setup_spec

  def count_of(type)
    Ktistec.database.scalar("SELECT COUNT(*) FROM relationships WHERE type = ?", type).as(Int64)
  end

  def insert_relationship(type, from_iri, to_iri)
    Ktistec.database.exec(
      "INSERT INTO relationships (created_at, updated_at, type, from_iri, to_iri, confirmed, visible) VALUES (?, ?, ?, ?, ?, 1, 1)",
      Time.utc, Time.utc, type, from_iri, to_iri,
    )
  end

  describe ".run" do
    let(account) { register }
    let_create(:actor, named: other)
    let_create(:object, attributed_to: account.actor)
    let_create(:like, named: like_activity, actor: other, object: object)

    context "given a legacy bare Timeline row" do
      before_each { insert_relationship("Relationship::Content::Timeline", account.actor.iri, object.iri) }

      it "purges it" do
        expect { described_class.run(Ktistec.database) }
          .to change { count_of("Relationship::Content::Timeline") }.from(1).to(0)
      end
    end

    context "given a legacy bare Notification row" do
      before_each { insert_relationship("Relationship::Content::Notification", account.actor.iri, like_activity.iri) }

      it "purges it" do
        expect { described_class.run(Ktistec.database) }
          .to change { count_of("Relationship::Content::Notification") }.from(1).to(0)
      end
    end

    context "given a create in the owner's inbox" do
      let_create(:object, named: post, attributed_to: other)
      let_create(:create, named: create_activity, actor: other, object: post)

      before_each { put_in_inbox(account.actor, create_activity) }

      it "materializes the timeline entry" do
        expect { described_class.run(Ktistec.database) }
          .to change { Relationship::Content::Timeline::Create.count(from_iri: account.actor.iri, to_iri: post.iri) }.from(0).to(1)
      end
    end

    context "given a like in the owner's inbox" do
      before_each { put_in_inbox(account.actor, like_activity) }

      it "materializes the like notification" do
        expect { described_class.run(Ktistec.database) }
          .to change { Relationship::Content::Notification::Like.count(from_iri: account.actor.iri, to_iri: like_activity.iri) }.from(0).to(1)
      end
    end

    context "given a stale like notification not backed by the inbox" do
      before_each { put_in_notifications(account.actor, activity: like_activity) }

      it "purges it" do
        expect { described_class.run(Ktistec.database) }
          .to change { Relationship::Content::Notification::Like.count(from_iri: account.actor.iri, to_iri: like_activity.iri) }.from(1).to(0)
      end
    end

    context "given an imperative quote notification" do
      let_create(:quote_request, actor: other, object: object)

      before_each { put_in_notifications(account.actor, activity: quote_request) }

      it "leaves it untouched" do # not reconciled
        expect { described_class.run(Ktistec.database) }
          .not_to change { Relationship::Content::Notification::Quote.count(from_iri: account.actor.iri, to_iri: quote_request.iri) }
      end
    end
  end
end
