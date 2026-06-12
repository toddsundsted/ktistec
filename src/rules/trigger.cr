require "./maintainer"
require "./view/follow_thread"
require "./view/follow_hashtag"
require "./view/follow_mention"
require "../models/activity_pub/activity"
require "../models/activity_pub/activity/announce"
require "../models/activity_pub/activity/dislike"
require "../models/activity_pub/activity/like"
require "../models/activity_pub/activity/undo"
require "../models/activity_pub/actor"
require "../models/relationship/content/follow/thread"
require "../models/relationship/content/follow/hashtag"
require "../models/relationship/content/follow/mention"
require "../models/tag/hashtag"
require "../models/tag/mention"
require "../models/account"
require "../framework/topic"

module Rules
  # The trigger.
  #
  # Maps a changed activity to the object whose materialized views
  # must be re-evaluated and drives the maintainer.
  #
  module Trigger
    extend self

    # the sink that delivers one notification to a pub/sub subject is
    # isolated behind a swappable proc so the wiring can be tested
    # synchronously.
    #
    DEFAULT_NOTIFIER = ->(subject : String) { Ktistec::Topic{subject}.notify_subscribers; nil }

    class_property notifier : Proc(String, Nil) = DEFAULT_NOTIFIER

    # Re-evaluates the materialized views for the object an activity
    # concerns.
    #
    def reconcile_for_activity(activity : ActivityPub::Activity) : Nil
      object_iri =
        if activity.is_a?(ActivityPub::Activity::Undo)
          activity.object?.try(&.object_iri)
        else
          activity.object_iri
        end
      notify(Rules::Maintainer.reconcile_object(object_iri)) if object_iri
    end

    # Re-evaluates the materialized views affected by a change to an
    # actor's state.
    #
    def reconcile_for_actor(actor : ActivityPub::Actor) : Nil
      object_iris = Ktistec.database.query_all(<<-SQL, actor.iri, ActivityPub::Activity::Announce.to_s, ActivityPub::Activity::Dislike.to_s, ActivityPub::Activity::Like.to_s, as: String)
        SELECT DISTINCT object_iri
          FROM activities
         WHERE actor_iri = ?
           AND type IN (?, ?, ?)
           AND undone_at IS NULL
           AND object_iri IS NOT NULL
        SQL
      object_iris += Ktistec.database.query_all(<<-SQL, Relationship::Content::Follow::Thread.to_s, actor.iri, as: String)
        SELECT DISTINCT o.iri
          FROM objects o
          JOIN relationships f ON f.type = ? AND f.to_iri = o.thread
         WHERE o.attributed_to_iri = ?
        SQL
      object_iris += Ktistec.database.query_all(<<-SQL, Tag::Hashtag.to_s, Relationship::Content::Follow::Hashtag.to_s, actor.iri, as: String)
        SELECT DISTINCT o.iri
          FROM objects o
          JOIN tags t ON t.subject_iri = o.iri AND t.type = ?
          JOIN relationships f ON f.type = ? AND f.to_iri = t.name
         WHERE o.attributed_to_iri = ?
        SQL
      object_iris += Ktistec.database.query_all(<<-SQL, Tag::Mention.to_s, Relationship::Content::Follow::Mention.to_s, actor.iri, as: String)
        SELECT DISTINCT o.iri
          FROM objects o
          JOIN tags t ON t.subject_iri = o.iri AND t.type = ?
          JOIN relationships f ON f.type = ? AND f.to_iri = t.href
         WHERE o.attributed_to_iri = ?
        SQL
      changed = [] of {Rules::View, String}
      object_iris.uniq.each do |object_iri|
        changed.concat(Rules::Maintainer.reconcile_object(object_iri))
      end
      notify(changed)
    end

    # Re-evaluates the thread-follow notification for an `(owner, thread)`
    # key.
    #
    def reconcile_for_thread(owner_iri : String, thread : String) : Nil
      view : Rules::View = Rules::View::FollowThread.instance
      key = {from_iri: owner_iri, to_iri: thread}
      notify([{view, owner_iri}]) if Rules::Maintainer.reconcile_for(view, key)
    end

    # :ditto:
    def reconcile_for_thread_follow(follow : Relationship::Content::Follow::Thread) : Nil
      reconcile_for_thread(follow.from_iri, follow.thread)
    end

    # Re-evaluates the hashtag-follow notification for an `(owner, name)`
    # key.
    #
    def reconcile_for_hashtag(owner_iri : String, name : String) : Nil
      view : Rules::View = Rules::View::FollowHashtag.instance
      key = {from_iri: owner_iri, to_iri: name}
      notify([{view, owner_iri}]) if Rules::Maintainer.reconcile_for(view, key)
    end

    # :ditto:
    def reconcile_for_hashtag_follow(follow : Relationship::Content::Follow::Hashtag) : Nil
      reconcile_for_hashtag(follow.from_iri, follow.name)
    end

    # Re-evaluates the mention-follow notification for an `(owner, href)`
    # key.
    #
    def reconcile_for_mention(owner_iri : String, href : String) : Nil
      view : Rules::View = Rules::View::FollowMention.instance
      key = {from_iri: owner_iri, to_iri: href}
      notify([{view, owner_iri}]) if Rules::Maintainer.reconcile_for(view, key)
    end

    # :ditto:
    def reconcile_for_mention_follow(follow : Relationship::Content::Follow::Mention) : Nil
      reconcile_for_mention(follow.from_iri, follow.href)
    end

    # Notifies the pub/sub subjects for the changed `(view, owner)` pairs,
    # waking subscribed clients to refresh.
    #
    private def notify(changed : Array({Rules::View, String})) : Nil
      subjects = [] of String
      changed.each do |(view, owner_iri)|
        if (account = Account.find?(iri: owner_iri))
          subjects.concat(view.subjects(account.username))
        end
      end
      subjects.uniq.each do |subject|
        Trigger.notifier.call(subject)
      end
    end
  end
end

# re-select representatives when a sender is blocked or unblocked.
ActivityPub::Actor::OBSERVERS.observe(:block) { |actor| Rules::Trigger.reconcile_for_actor(actor) }
ActivityPub::Actor::OBSERVERS.observe(:unblock) { |actor| Rules::Trigger.reconcile_for_actor(actor) }

# evict the thread-follow notification when its follow is removed.
Relationship::Content::Follow::Thread::OBSERVERS.observe(:destroy) { |follow| Rules::Trigger.reconcile_for_thread_follow(follow) }

# evict the hashtag-follow notification when its follow is removed.
Relationship::Content::Follow::Hashtag::OBSERVERS.observe(:destroy) { |follow| Rules::Trigger.reconcile_for_hashtag_follow(follow) }

# evict the mention-follow notification when its follow is removed.
Relationship::Content::Follow::Mention::OBSERVERS.observe(:destroy) { |follow| Rules::Trigger.reconcile_for_mention_follow(follow) }
