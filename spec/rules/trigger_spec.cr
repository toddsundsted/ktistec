require "../../src/rules/trigger"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Rules::Trigger do
  setup_spec

  let(actor) { register.actor }
  let(followed_at) { Time.utc(2026, 1, 1) }
  let(mention_name) { "foo@remote" }
  let(mention_href) { "https://remote.com/actors/foo" }

  let_build(:actor, named: author)
  let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo", created_at: followed_at)
  let_create!(:follow_mention_relationship, named: mention_follow, actor: actor, href: mention_href, created_at: followed_at)

  alias Notification = ::Relationship::Content::Notification

  def hashtag_notification_count(name)
    Notification::Follow::Hashtag.count(from_iri: actor.iri, to_iri: name)
  end

  def mention_notification_count(href)
    Notification::Follow::Mention.count(from_iri: actor.iri, to_iri: href)
  end

  describe ".reconcile_for_activity" do
    let_create!(:object, named: post, attributed_to: author, created_at: followed_at + 1.hour)
    let_create!(:hashtag, name: "foo", subject: post)
    let_create!(:create, named: activity, actor: author, object: post)

    it "materializes the hashtag-follow notification for the activity's tagged object" do
      expect { Rules::Trigger.reconcile_for_activity(activity) }
        .to change { hashtag_notification_count("foo") }.from(0).to(1)
    end
  end

  # set `blocked_at` via `assign` and call `reconcile_for_actor`
  # directly rather than via `block!`/`unblock!`. `block!` also fires
  # the observer wiring, conflating the method's logic with its
  # wiring, which is tested separately.
  describe ".reconcile_for_actor" do
    context "given a followed hashtag" do
      let_create!(:object, named: post, attributed_to: author, created_at: followed_at + 2.hours)
      let_create!(:hashtag, name: "foo", subject: post)

      it "materializes the notification for the author's tagged post" do
        expect { Rules::Trigger.reconcile_for_actor(author) }
          .to change { hashtag_notification_count("foo") }.from(0).to(1)
      end

      context "when a notification exists and the author is blocked" do
        let_create!(:notification_follow_hashtag, owner: actor, name: "foo", created_at: post.created_at)

        before_each { author.assign(blocked_at: followed_at + 3.hours).save }

        it "evicts the notification" do
          expect { Rules::Trigger.reconcile_for_actor(author) }
            .to change { hashtag_notification_count("foo") }.from(1).to(0)
        end

        context "and an earlier post from an unblocked author exists" do
          let_create!(:actor, named: unblocked)
          let_create!(:object, named: earlier, attributed_to: unblocked, created_at: followed_at + 1.hour)
          let_create!(:hashtag, named: nil, name: "foo", subject: earlier)

          it "falls back to the earlier author's post" do
            expect { Rules::Trigger.reconcile_for_actor(author) }
              .to change { Notification::Follow::Hashtag.find?(from_iri: actor.iri, to_iri: "foo").try(&.created_at) }
                .from(post.created_at).to(earlier.created_at)
          end
        end
      end
    end

    context "given a followed mention" do
      let_create!(:object, named: post, attributed_to: author, created_at: followed_at + 2.hours)
      let_create!(:mention, name: mention_name, href: mention_href, subject: post)

      it "materializes the notification for the author's mentioning post" do
        expect { Rules::Trigger.reconcile_for_actor(author) }
          .to change { mention_notification_count(mention_href) }.from(0).to(1)
      end

      context "when a notification exists and the author is blocked" do
        let_create!(:notification_follow_mention, owner: actor, href: mention_href, created_at: post.created_at)

        before_each { author.assign(blocked_at: followed_at + 3.hours).save }

        it "evicts the notification" do
          expect { Rules::Trigger.reconcile_for_actor(author) }
            .to change { mention_notification_count(mention_href) }.from(1).to(0)
        end

        context "and an earlier post from an unblocked author exists" do
          let_create!(:actor, named: unblocked)
          let_create!(:object, named: earlier, attributed_to: unblocked, created_at: followed_at + 1.hour)
          let_create!(:mention, named: nil, name: mention_name, href: mention_href, subject: earlier)

          it "falls back to the earlier author's post" do
            expect { Rules::Trigger.reconcile_for_actor(author) }
              .to change { Notification::Follow::Mention.find?(from_iri: actor.iri, to_iri: mention_href).try(&.created_at) }
                .from(post.created_at).to(earlier.created_at)
          end
        end
      end
    end
  end

  describe ".reconcile_for_hashtag" do
    let(appeared_at) { followed_at + 1.hour }
    let_create!(:object, named: post, attributed_to: author, created_at: appeared_at)
    let_create!(:hashtag, name: "foo", subject: post)

    it "materializes the hashtag-follow notification for a qualifying object" do
      expect { Rules::Trigger.reconcile_for_hashtag(actor.iri, "foo") }
        .to change { hashtag_notification_count("foo") }.from(0).to(1)
    end

    context "when the object appeared before the follow" do
      let(appeared_at) { followed_at - 1.hour }

      it "does not materialize the notification" do
        expect { Rules::Trigger.reconcile_for_hashtag(actor.iri, "foo") }
          .not_to change { hashtag_notification_count("foo") }
      end
    end
  end

  describe ".reconcile_for_mention" do
    let(appeared_at) { followed_at + 1.hour }
    let_create!(:object, named: post, attributed_to: author, created_at: appeared_at)
    let_create!(:mention, name: mention_name, href: mention_href, subject: post)

    it "materializes the mention-follow notification for a qualifying object" do
      expect { Rules::Trigger.reconcile_for_mention(actor.iri, mention_href) }
        .to change { mention_notification_count(mention_href) }.from(0).to(1)
    end

    context "when the object appeared before the follow" do
      let(appeared_at) { followed_at - 1.hour }

      it "does not materialize the notification" do
        expect { Rules::Trigger.reconcile_for_mention(actor.iri, mention_href) }
          .not_to change { mention_notification_count(mention_href) }
      end
    end
  end

  describe "when a hashtag-follow is destroyed" do
    let_create!(:notification_follow_hashtag, owner: actor, name: "foo")

    pre_condition { expect(hashtag_notification_count("foo")).to eq(1) }

    it "evicts the hashtag-follow notification" do
      expect { hashtag_follow.destroy }
        .to change { hashtag_notification_count("foo") }.from(1).to(0)
    end
  end

  describe "when a mention-follow is destroyed" do
    let_create!(:notification_follow_mention, owner: actor, href: mention_href)

    pre_condition { expect(mention_notification_count(mention_href)).to eq(1) }

    it "evicts the mention-follow notification" do
      expect { mention_follow.destroy }
        .to change { mention_notification_count(mention_href) }.from(1).to(0)
    end
  end
end
