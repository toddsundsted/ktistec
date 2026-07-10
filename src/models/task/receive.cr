require "../task"
require "../task/mixins/transfer"

require "../activity_pub/activity"
require "../activity_pub/activity/update"
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
      state.recipients || [] of String
    end

    def recipients=(@recipients : Array(String)?)
      state.recipients = recipients
    end

    def perform
      if (activity = self.activity) && (activity.is_a?(ActivityPub::Activity::ObjectActivity) || activity.is_a?(ActivityPub::Activity::Update)) && (object = activity.object?) && object.is_a?(ActivityPub::Object)
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
