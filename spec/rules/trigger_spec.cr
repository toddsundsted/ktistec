require "../../src/rules/trigger"
require "../../src/rules/feeds"
require "../../src/models/feed"
require "../../src/models/feed/verdict"
require "../../src/services/feed/backend/criteria"
require "../../src/models/relationship/content/public_tagged"
require "../../src/models/relationship/content/notification/follow/hashtag"
require "../../src/models/relationship/content/notification/follow/mention"
require "../../src/models/relationship/content/notification/follow/thread"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Rules::Trigger do
  setup_spec

  let(actor) { register.actor }
  let(mention_name) { "foo@remote" }
  let(mention_href) { "https://remote.com/actors/foo" }

  let_build(:actor, named: author)

  alias Notification = ::Relationship::Content::Notification

  def thread_notification_count(thread)
    Notification::Follow::Thread.count(from_iri: actor.iri, to_iri: thread)
  end

  def hashtag_notification_count(name)
    Notification::Follow::Hashtag.count(from_iri: actor.iri, to_iri: name)
  end

  def mention_notification_count(href)
    Notification::Follow::Mention.count(from_iri: actor.iri, to_iri: href)
  end

  def feed_row_count(feed)
    Ktistec.database.query_one("SELECT COUNT(*) FROM relationships WHERE type = ?", feed.feed_type, as: Int64)
  end

  around_each do |proc|
    saved = Rules::View.registry.dup
    begin
      proc.call
    ensure
      Rules::View.registry.clear
      Rules::View.registry.concat(saved)
    end
  end

  describe ".reconcile_for_activity" do
    let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
    let_create!(:object, named: post, attributed_to: author)
    let_create!(:hashtag, name: "foo", subject: post)
    let_create!(:create, named: activity, actor: author, object: post)

    it "materializes the hashtag-follow notification for the activity's tagged object" do
      expect { Rules::Trigger.reconcile_for_activity(activity) }
        .to change { hashtag_notification_count("foo") }.from(0).to(1)
    end

    context "given a registered feed and a matching object in the owner's inbox" do
      let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

      before_each do
        post.assign(content: "<p>something alpha something</p>").save
        put_in_inbox(actor, activity)
        Rules::Feeds.register(feed)
      end

      it "materializes the arriving object into the feed" do
        expect { Rules::Trigger.reconcile_for_activity(activity) }
          .to change { feed_row_count(feed) }.from(0).to(1)
      end

      context "and the activity is an Undo" do
        let_create!(:announce, actor: author, object: post)
        let_create!(:undo, named: activity, actor: author, object: announce)

        pre_condition { expect(activity.object?.try(&.object_iri)).to eq(post.iri) }

        it "materializes the undone activity's object into the feed" do
          expect { Rules::Trigger.reconcile_for_activity(activity) }
            .to change { feed_row_count(feed) }.from(0).to(1)
        end
      end

      context "and the object is not visible" do
        before_each { post.update_property(:visible, false) }

        pre_condition { expect(Feed::Candidates.arrival_for(feed, post)).not_to be_nil }

        it "materializes the arriving object into the feed" do
          expect { Rules::Trigger.reconcile_for_activity(activity) }
            .to change { feed_row_count(feed) }.from(0).to(1)
        end
      end
    end
  end

  describe ".reconcile_for_object" do
    let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
    let_create!(:object, named: post, attributed_to: author, content: "<p>something alpha something</p>")

    before_each { Rules::Feeds.register(feed) }

    it "materializes a matching object into the feed" do
      expect { Rules::Trigger.reconcile_for_object(post) }
        .to change { feed_row_count(feed) }.from(0).to(1)
    end

    it "writes the verdict before materializing it" do
      expect { Rules::Trigger.reconcile_for_object(post) }
        .to change { Feed::Verdict.count(feed_id: feed.id, included: true) }.from(0).to(1)
    end

    context "given a member" do
      before_each { Rules::Trigger.reconcile_for_object(post) }

      pre_condition { expect(feed_row_count(feed)).to eq(1) }

      context "when an edit ends its candidacy" do
        before_each { post.update_property(:visible, false) }

        pre_condition { expect(Feed::Candidates.arrival_for(feed, post)).to be_nil }

        it "evicts the feed row" do
          expect { Rules::Trigger.reconcile_for_object(post) }
            .to change { feed_row_count(feed) }.from(1).to(0)
        end
      end

      context "when an edit stops it matching" do
        before_each { post.update_property(:content, "<p>nothing of interest</p>") }

        it "evicts the feed row" do
          expect { Rules::Trigger.reconcile_for_object(post) }
            .to change { feed_row_count(feed) }.from(1).to(0)
        end
      end
    end
  end

  describe "when an object is saved" do
    let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)

    before_each { Rules::Feeds.register(feed) }

    let_build(:object, named: post, attributed_to: author, content: "<p>something alpha something</p>")

    it "materializes the object into the feed" do
      expect { post.save }
        .to change { feed_row_count(feed) }.from(0).to(1)
    end
  end

  # set `blocked_at` via `assign` and call `reconcile_for_actor`
  # directly rather than via `block!`/`unblock!`. `block!` also fires
  # the observer wiring, conflating the method's logic with its
  # wiring, which is tested separately.
  describe ".reconcile_for_actor" do
    context "given a followed thread" do
      let_create!(:object, named: thread_root, attributed_to: author)
      let_create!(:follow_thread_relationship, named: thread_follow, actor: actor, thread: thread_root.iri)
      let_create!(:object, named: post, attributed_to: author, in_reply_to: thread_root, created_at: thread_follow.created_at + 2.seconds)

      it "materializes the notification for the author's reply" do
        expect { Rules::Trigger.reconcile_for_actor(author) }
          .to change { thread_notification_count(thread_root.iri) }.from(0).to(1)
      end

      context "when a notification exists and the author is blocked" do
        let_create!(:notification_follow_thread, owner: actor, object: thread_root, created_at: post.created_at)

        before_each { author.assign(blocked_at: post.created_at + 1.second).save }

        it "evicts the notification" do
          expect { Rules::Trigger.reconcile_for_actor(author) }
            .to change { thread_notification_count(thread_root.iri) }.from(1).to(0)
        end

        context "and an earlier reply from an unblocked author exists" do
          let_create!(:actor, named: unblocked)
          let_create!(:object, named: earlier, attributed_to: unblocked, in_reply_to: thread_root, created_at: thread_follow.created_at + 1.second)

          it "falls back to the earlier author's reply" do
            expect { Rules::Trigger.reconcile_for_actor(author) }
              .to change { Notification::Follow::Thread.find?(from_iri: actor.iri, to_iri: thread_root.iri).try(&.created_at) }
                .from(post.created_at).to(earlier.created_at)
          end
        end
      end
    end

    context "given a followed hashtag" do
      let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
      let_create!(:object, named: post, attributed_to: author, created_at: hashtag_follow.created_at + 2.seconds)
      let_create!(:hashtag, name: "foo", subject: post)

      it "materializes the notification for the author's tagged post" do
        expect { Rules::Trigger.reconcile_for_actor(author) }
          .to change { hashtag_notification_count("foo") }.from(0).to(1)
      end

      context "when a notification exists and the author is blocked" do
        let_create!(:notification_follow_hashtag, owner: actor, name: "foo", created_at: post.created_at)

        before_each { author.assign(blocked_at: post.created_at + 1.second).save }

        it "evicts the notification" do
          expect { Rules::Trigger.reconcile_for_actor(author) }
            .to change { hashtag_notification_count("foo") }.from(1).to(0)
        end

        context "and an earlier post from an unblocked author exists" do
          let_create!(:actor, named: unblocked)
          let_create!(:object, named: earlier, attributed_to: unblocked, created_at: hashtag_follow.created_at + 1.second)
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
      let_create!(:follow_mention_relationship, named: mention_follow, actor: actor, href: mention_href)
      let_create!(:object, named: post, attributed_to: author, created_at: mention_follow.created_at + 2.seconds)
      let_create!(:mention, name: mention_name, href: mention_href, subject: post)

      it "materializes the notification for the author's mentioning post" do
        expect { Rules::Trigger.reconcile_for_actor(author) }
          .to change { mention_notification_count(mention_href) }.from(0).to(1)
      end

      context "when a notification exists and the author is blocked" do
        let_create!(:notification_follow_mention, owner: actor, href: mention_href, created_at: post.created_at)

        before_each { author.assign(blocked_at: post.created_at + 1.second).save }

        it "evicts the notification" do
          expect { Rules::Trigger.reconcile_for_actor(author) }
            .to change { mention_notification_count(mention_href) }.from(1).to(0)
        end

        context "and an earlier post from an unblocked author exists" do
          let_create!(:actor, named: unblocked)
          let_create!(:object, named: earlier, attributed_to: unblocked, created_at: mention_follow.created_at + 1.second)
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

  describe ".reconcile_for_thread" do
    let(appeared_at) { thread_follow.created_at + 1.second }
    let_create!(:object, named: thread_root, attributed_to: author)
    let_create!(:follow_thread_relationship, named: thread_follow, actor: actor, thread: thread_root.iri)
    let_create!(:object, named: post, attributed_to: author, in_reply_to: thread_root, created_at: appeared_at)

    it "materializes the thread-follow notification for a qualifying object" do
      expect { Rules::Trigger.reconcile_for_thread(actor.iri, thread_root.iri) }
        .to change { thread_notification_count(thread_root.iri) }.from(0).to(1)
    end

    context "when the object appeared before the follow" do
      let(appeared_at) { thread_follow.created_at - 1.second }

      it "does not materialize the notification" do
        expect { Rules::Trigger.reconcile_for_thread(actor.iri, thread_root.iri) }
          .not_to change { thread_notification_count(thread_root.iri) }
      end
    end
  end

  describe ".reconcile_for_hashtag" do
    let(appeared_at) { hashtag_follow.created_at + 1.second }
    let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
    let_create!(:object, named: post, attributed_to: author, created_at: appeared_at)
    let_create!(:hashtag, name: "foo", subject: post)

    it "materializes the hashtag-follow notification for a qualifying object" do
      expect { Rules::Trigger.reconcile_for_hashtag(actor.iri, "foo") }
        .to change { hashtag_notification_count("foo") }.from(0).to(1)
    end

    context "when the object appeared before the follow" do
      let(appeared_at) { hashtag_follow.created_at - 1.second }

      it "does not materialize the notification" do
        expect { Rules::Trigger.reconcile_for_hashtag(actor.iri, "foo") }
          .not_to change { hashtag_notification_count("foo") }
      end
    end
  end

  describe ".reconcile_for_mention" do
    let(appeared_at) { mention_follow.created_at + 1.second }
    let_create!(:follow_mention_relationship, named: mention_follow, actor: actor, href: mention_href)
    let_create!(:object, named: post, attributed_to: author, created_at: appeared_at)
    let_create!(:mention, name: mention_name, href: mention_href, subject: post)

    it "materializes the mention-follow notification for a qualifying object" do
      expect { Rules::Trigger.reconcile_for_mention(actor.iri, mention_href) }
        .to change { mention_notification_count(mention_href) }.from(0).to(1)
    end

    context "when the object appeared before the follow" do
      let(appeared_at) { mention_follow.created_at - 1.second }

      it "does not materialize the notification" do
        expect { Rules::Trigger.reconcile_for_mention(actor.iri, mention_href) }
          .not_to change { mention_notification_count(mention_href) }
      end
    end
  end

  # each entry point that drives the maintainer must notify the
  # owner's subject. the subject family (notifications vs. timeline)
  # is incidental here: `notify` forwards `view.subjects`
  # view-agnostically, so which family a subject belongs to is the
  # view's concern, covered by the per-view `subjects` specs.
  # notifications covers all the testable entry points.

  describe "notifying" do
    let(notified) { [] of String }
    let(owner_subject) { "/actors/#{actor.username}/notifications" }

    before_each { Rules::Trigger.notifier = ->(subject : String) { notified << subject; nil } }
    after_each { Rules::Trigger.notifier = Rules::Trigger::DEFAULT_NOTIFIER }

    context "via reconcile_for_activity" do
      let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
      let_create!(:object, named: post, attributed_to: author)
      let_create!(:create, named: activity, actor: author, object: post)
      let_create!(:hashtag, name: "foo", subject: post)

      it "notifies the owner's notifications subject" do
        Rules::Trigger.reconcile_for_activity(activity)
        expect(notified).to eq([owner_subject])
      end
    end

    context "via reconcile_for_actor" do
      let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
      let_create!(:object, named: post, attributed_to: author)
      let_create!(:hashtag, name: "foo", subject: post)

      it "notifies the owner's notifications subject" do
        Rules::Trigger.reconcile_for_actor(author)
        expect(notified).to eq([owner_subject])
      end
    end

    context "via reconcile_for_object" do
      let_create!(:feed, owner: actor, params: JSON.parse(%({"keywords": {"any": ["alpha"]}})).as_h)
      let_create!(:object, named: post, attributed_to: author, content: "<p>something alpha something</p>")

      before_each { Rules::Feeds.register(feed) }

      it "notifies the owner's feed subject" do
        Rules::Trigger.reconcile_for_object(post)
        expect(notified).to eq(["/actors/#{actor.username}/feeds/#{feed.id}"])
      end
    end

    context "via reconcile_for_thread" do
      let_create!(:object, named: thread_root, attributed_to: author)
      let_create!(:follow_thread_relationship, named: thread_follow, actor: actor, thread: thread_root.iri)
      let_create!(:object, named: post, attributed_to: author, in_reply_to: thread_root)

      it "notifies the owner's notifications subject" do
        Rules::Trigger.reconcile_for_thread(actor.iri, thread_root.iri)
        expect(notified).to eq([owner_subject])
      end
    end

    context "via reconcile_for_mention" do
      let_create!(:follow_mention_relationship, named: mention_follow, actor: actor, href: mention_href)
      let_create!(:object, named: post, attributed_to: author)
      let_create!(:mention, name: mention_name, href: mention_href, subject: post)

      it "notifies the owner's notifications subject" do
        Rules::Trigger.reconcile_for_mention(actor.iri, mention_href)
        expect(notified).to eq([owner_subject])
      end
    end

    context "via reconcile_for_hashtag" do
      let(appeared_at) { hashtag_follow.created_at + 1.second }
      let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
      let_create!(:object, named: post, attributed_to: author, created_at: appeared_at)
      let_create!(:hashtag, name: "foo", subject: post)

      it "notifies the owner's notifications subject" do
        Rules::Trigger.reconcile_for_hashtag(actor.iri, "foo")
        expect(notified).to eq([owner_subject])
      end

      context "when nothing materializes" do
        let(appeared_at) { hashtag_follow.created_at - 1.second }

        pre_condition { expect(hashtag_notification_count("foo")).to eq(0) }

        it "does not notify" do
          Rules::Trigger.reconcile_for_hashtag(actor.iri, "foo")
          expect(notified).to be_empty
        end
      end
    end
  end

  describe "when a thread-follow is destroyed" do
    let_create!(:object, named: thread_root, attributed_to: author)
    let_create!(:follow_thread_relationship, named: thread_follow, actor: actor, thread: thread_root.iri)
    let_create!(:notification_follow_thread, owner: actor, object: thread_root)

    pre_condition { expect(thread_notification_count(thread_root.iri)).to eq(1) }

    it "evicts the thread-follow notification" do
      expect { thread_follow.destroy }
        .to change { thread_notification_count(thread_root.iri) }.from(1).to(0)
    end
  end

  describe "when a hashtag-follow is destroyed" do
    let_create!(:follow_hashtag_relationship, named: hashtag_follow, actor: actor, name: "foo")
    let_create!(:notification_follow_hashtag, owner: actor, name: "foo")

    pre_condition { expect(hashtag_notification_count("foo")).to eq(1) }

    it "evicts the hashtag-follow notification" do
      expect { hashtag_follow.destroy }
        .to change { hashtag_notification_count("foo") }.from(1).to(0)
    end
  end

  describe "when a mention-follow is destroyed" do
    let_create!(:follow_mention_relationship, named: mention_follow, actor: actor, href: mention_href)
    let_create!(:notification_follow_mention, owner: actor, href: mention_href)

    pre_condition { expect(mention_notification_count(mention_href)).to eq(1) }

    it "evicts the mention-follow notification" do
      expect { mention_follow.destroy }
        .to change { mention_notification_count(mention_href) }.from(1).to(0)
    end
  end

  describe "given a public-timeline member" do
    let_create(:object, named: post, attributed_to: author)
    let_create!(:public_timeline, object: post)

    context "when a hashtag is added" do
      it "materializes the public-tagged row" do
        expect { Factory.create(:hashtag, name: "bar", subject: post) } # ameba:disable Ktistec/NoImperativeFactories
          .to change { Relationship::Content::PublicTagged.count(to_iri: post.iri) }.from(0).to(1)
      end
    end

    context "when a hashtag is removed" do
      let_create!(:hashtag, named: tag, name: "bar", subject: post)

      it "evicts the public-tagged row" do
        expect { tag.destroy }
          .to change { Relationship::Content::PublicTagged.count(to_iri: post.iri) }.from(1).to(0)
      end
    end
  end
end
