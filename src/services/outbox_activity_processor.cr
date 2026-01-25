require "../models/activity_pub/activity"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/account"
require "../rules/content_rules"
require "../models/task/deliver"
require "../models/task/distribute_poll_updates"
require "../models/task/notify_poll_expiry"
require "../models/relationship/social/follow"

class OutboxActivityProcessor
  # Processes an outbound activity that has already been created,
  # validated, and saved.
  #
  # Processes the activity through content rules, handles
  # activity-specific side-effects, and schedules delivery task.
  #
  # Preconditions:
  # - activity must be saved
  # - activity must be local
  # - activity actor must equal account actor
  # - For accept/reject: The follow relationship must exist
  # - For undo: The activity being undone must exist and be owned by the same actor
  # - For delete: The object/actor being deleted must be local and owned by the account
  #
  def self.process(
    account : Account,
    activity : ActivityPub::Activity,
    content_rules : ContentRules = ContentRules.new,
    deliver_task_class : Task::Deliver.class = Task::Deliver,
  )
    content_rules.run do
      assert ContentRules::Outgoing.new(account.actor, activity)
    end

    case activity
    when ActivityPub::Activity::Create
      case (object = activity.object)
      when ActivityPub::Object::Question
        if object.local? && !Task::DistributePollUpdates.find?(question: object)
          Task::DistributePollUpdates.new(
            actor: activity.actor,
            question: object
          ).schedule(Task::DistributePollUpdates::CHECK_INTERVAL.from_now)
        end
        if object.local?
          if (poll = object.poll?)
            if (closed_at = poll.closed_at)
              if closed_at > Time.utc
                unless Task::NotifyPollExpiry.find?(question: object)
                  Task::NotifyPollExpiry.new(source_iri: "", question: object).schedule(closed_at)
                end
              end
            end
          end
        end
      end
    when ActivityPub::Activity::Follow
      unless Relationship::Social::Follow.find?(actor: activity.actor, object: activity.object, visible: false)
        Relationship::Social::Follow.new(
          actor: activity.actor,
          object: activity.object,
          visible: false
        ).save(skip_associated: true)
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

    deliver_task_class.new(
      sender: account.actor,
      activity: activity
    ).schedule
  end
end
