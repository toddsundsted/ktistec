require "../task"
require "../task/mixins/transfer"

require "../../framework/constants"
require "../activity_pub/activity"
require "../activity_pub/actor"
require "../activity_pub/collection"
require "../activity_pub/object"
require "../relationship/social/follow"

class Task
  class Deliver < Task
    include Ktistec::Constants
    include Task::ConcurrentTask
    include Task::Transfer

    belongs_to sender, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(sender) { "missing: #{source_iri}" unless sender? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    def recipients
      [activity.to, activity.cc, sender.iri].flatten.flat_map do |recipient|
        if recipient == PUBLIC
          # no-op
        elsif recipient == sender.iri
          sender.iri
        elsif recipient && (actor = ActivityPub::Actor.dereference?(sender, recipient))
          actor.iri
        elsif recipient && recipient =~ /^#{sender.iri}\/followers$/
          Relationship::Social::Follow.where(
            to_iri: sender.iri,
            confirmed: true
          ).select(&.actor?).map(&.actor.iri)
        end
      end.compact.sort.uniq
    end

    def perform
      transfer activity, from: sender, to: recipients
    end
  end
end
