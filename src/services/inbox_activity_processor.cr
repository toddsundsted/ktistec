require "../models/activity_pub/activity"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/account"
require "../rules/content_rules"
require "../models/task/handle_follow_request"
require "../models/task/receive"
require "../models/relationship/social/follow"

class InboxActivityProcessor
  # Processes an inbound activity that has already been received,
  # validated, and saved.
  #
  # Processes the activity through content rules, handles
  # activity-specific side-effects, and schedules receive task.
  #
  # Preconditions:
  # - activity must be saved
  # - activity must be from a remote actor
  # - account.actor must be the recipient
  #
  def self.process(
       account : Account,
       activity : ActivityPub::Activity,
       deliver_to : Array(String)? = nil,
       content_rules : ContentRules = ContentRules.new,
       handle_follow_request_task_class : Task::HandleFollowRequest.class = Task::HandleFollowRequest,
       receive_task_class : Task::Receive.class = Task::Receive
     )
    content_rules.run do
      recipients = [activity.to, activity.cc, deliver_to].flatten.compact.uniq
      recipients.each { |recipient| assert ContentRules::IsRecipient.new(recipient) }
      assert ContentRules::Incoming.new(account.actor, activity)
    end

    case activity
    when ActivityPub::Activity::Follow
      if activity.object == account.actor
        unless Relationship::Social::Follow.find?(actor: activity.actor, object: activity.object)
          Relationship::Social::Follow.new(
            actor: activity.actor,
            object: activity.object,
            visible: false
          ).save(skip_associated: true)
        end
        handle_follow_request_task_class.new(
          recipient: account.actor,
          activity: activity
        ).schedule
      end
    when ActivityPub::Activity::Accept
      if (follow = Relationship::Social::Follow.find?(actor: activity.object.actor, object: activity.object.object))
        follow.assign(confirmed: true).save
      end
    when ActivityPub::Activity::Reject
      if (follow = Relationship::Social::Follow.find?(actor: activity.object.actor, object: activity.object.object))
        follow.assign(confirmed: true).save
      end
    when ActivityPub::Activity::Undo
      case (object = activity.object)
      when ActivityPub::Activity::Follow
        if (follow = Relationship::Social::Follow.find?(actor: object.actor, object: object.object))
          follow.destroy
        end
      end
      activity.object.undo!
    when ActivityPub::Activity::Delete
      case (object = activity.object?)
      when ActivityPub::Object
        object.delete!
      when ActivityPub::Actor
        object.delete!
      end
    end

    receive_task_class.new(
      receiver: account.actor,
      activity: activity,
      deliver_to: deliver_to
    ).schedule
  end
end
