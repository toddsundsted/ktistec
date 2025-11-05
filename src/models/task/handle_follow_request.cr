require "../task"
require "../../services/outbox_activity_processor"
require "../../framework/util"
require "../activity_pub/activity/follow"
require "../activity_pub/activity/accept"
require "../relationship/social/follow"
require "../account"

class Task
  class HandleFollowRequest < Task
    belongs_to recipient, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(recipient) { "missing: #{source_iri}" unless recipient? }

    belongs_to activity, class_name: ActivityPub::Activity::Follow, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    def perform
      return unless recipient? && activity?

      account = Account.find?(iri: recipient.iri)
      return unless account

      if account.auto_approve_followers
        accept_activity = ActivityPub::Activity::Accept.new(
          iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
          actor: account.actor,
          object: activity,
          to: [activity.actor.iri]
        ).save

        OutboxActivityProcessor.process(account, accept_activity)
      end

      if account.auto_follow_back
        return if Relationship::Social::Follow.find?(actor: account.actor, object: activity.actor)
        return if ActivityPub::Activity::Follow.find?(actor: account.actor, object: activity.actor)

        follow_activity = ActivityPub::Activity::Follow.new(
          iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
          actor: account.actor,
          object: activity.actor,
          to: [activity.actor.iri]
        ).save

        OutboxActivityProcessor.process(account, follow_activity)
      end
    end
  end
end
