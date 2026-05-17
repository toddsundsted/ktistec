require "../task"
require "../task/mixins/transfer"

require "../../utils/recipients"
require "../activity_pub/activity"
require "../activity_pub/actor"
require "../activity_pub/collection"
require "../activity_pub/object"

class Task
  class Deliver < Task
    include Task::ConcurrentTask
    include Task::Transfer

    belongs_to sender, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(sender) { "missing: #{source_iri}" unless sender? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    class State
      include JSON::Serializable

      property recipients : Array(String)?

      def initialize(@recipients = nil)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    @[Assignable]
    @recipients : Array(String)?

    def recipients
      # fallback for in-flight tasks enqueued before the processor began
      state.recipients || Ktistec::Recipients.for_deliver(activity, sender)
    end

    def recipients=(@recipients : Array(String)?)
      state.recipients = recipients
    end

    def perform
      transfer activity, from: sender, to: recipients
    end
  end
end
