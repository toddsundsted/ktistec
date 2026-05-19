require "../task"
require "../task/mixins/transfer"

require "../../utils/recipients"
require "../activity_pub/activity"
require "../activity_pub/actor"
require "../activity_pub/collection"
require "../activity_pub/object"
require "../activity_pub/object/quote_authorization"

class Task
  class Receive < Task
    include Task::ConcurrentTask
    include Task::Transfer

    belongs_to receiver, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(receiver) { "missing: #{source_iri}" unless receiver? }

    belongs_to activity, class_name: ActivityPub::Activity, foreign_key: subject_iri, primary_key: iri
    validates(activity) { "missing: #{subject_iri}" unless activity? }

    class State
      include JSON::Serializable

      property deliver_to : Array(String)?

      property recipients : Array(String)?

      def initialize(@deliver_to = [] of String, @recipients = nil)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    @[Assignable]
    @deliver_to : Array(String)?

    @[Assignable]
    @recipients : Array(String)?

    def deliver_to
      state.deliver_to
    end

    def deliver_to=(@deliver_to : Array(String)?)
      state.deliver_to = deliver_to
    end

    def recipients
      # fallback for in-flight tasks enqueued before the processor began
      state.recipients || Ktistec::Recipients.for_receive(activity, receiver, deliver_to)
    end

    def recipients=(@recipients : Array(String)?)
      state.recipients = recipients
    end

    def perform
      if (activity = self.activity) && activity.is_a?(ActivityPub::Activity::ObjectActivity) && (object = activity.object?)
        if (quote = object.quote?(include_deleted: true) || object.quote?(receiver, dereference: true))
          if quote.attributed_to?(include_deleted: true) || quote.attributed_to?(receiver, dereference: true)
            quote.save
          end
          if !object.local? && object.attributed_to != quote.attributed_to
            if (quote_authorization = object.quote_authorization?(receiver, dereference: true))
              if quote_authorization.valid_for?(object, quote)
                quote_authorization.save
              end
            end
          end
        end
      end

      transfer activity, from: receiver, to: recipients
    end
  end
end
