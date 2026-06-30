require "../ktistec/constants"
require "../models/account"
require "../models/activity_pub/activity/update"
require "../models/activity_pub/actor"
require "../models/task/deliver"
require "./outbox_activity_processor"

# Federates a local user's profile changes.
#
module ActorUpdateDistributor
  Log = ::Log.for(self)

  # Builds, validates, saves, and distributes an `Update(Actor)`.
  #
  def self.distribute(account : Account, deliver_task_class : Task::Deliver.class = Task::Deliver) : Nil
    actor = account.actor
    activity = ActivityPub::Activity::Update.new(
      iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
      actor: actor,
      object: actor,
      published: Time.utc,
      visible: false,
      to: [Ktistec::Constants::PUBLIC],
      cc: [actor.followers].compact,
    )
    unless activity.valid_for_send?
      Log.warn { "actor update not valid for send: #{activity.errors.inspect}" }
      return
    end
    activity.save
    OutboxActivityProcessor.process(account, activity, deliver_task_class)
  rescue ex
    Log.warn(exception: ex) { "failed to distribute actor update for #{account.actor.iri}" }
  end
end
