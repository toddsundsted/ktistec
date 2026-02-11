require "../task"
require "../../services/outbox_activity_processor"
require "../activity_pub/activity/create"
require "../activity_pub/actor"
require "../activity_pub/object"
require "../account"

class Task
  class DeliverDelayedObject < Task
    Log = ::Log.for(self)

    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(actor) { "missing: #{source_iri}" unless actor? }

    belongs_to object, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(object) { "missing: #{subject_iri}" unless object? }

    class State
      include JSON::Serializable

      enum Reason
        PendingQuoteAuthorization
        Scheduled
      end

      class PendingQuoteAuthorizationContext
        include JSON::Serializable

        property quote_request_iri : String

        def initialize(@quote_request_iri)
        end
      end

      class ScheduledContext
        include JSON::Serializable

        property scheduled_at : Time

        def initialize(@scheduled_at)
        end
      end

      property reason : Reason

      property context : PendingQuoteAuthorizationContext | ScheduledContext

      def initialize(@reason, @context)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State

    delegate :reason, to: state

    def perform
      if (object = self.object?) && !object.deleted? && !object.published
        unless object.local?
          Log.warn { "non-local object: #{subject_iri}" }
          return
        end
        if (actor = object.attributed_to?) && !actor.deleted?
          unless (account = Account.find?(iri: actor.iri))
            Log.warn { "account not found: #{actor.iri}" }
            return
          end
          unless actor.in_outbox?(object, ActivityPub::Activity::Create)
            time = Time.utc
            activity = ActivityPub::Activity::Create.new(
              iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
              actor: actor,
              object: object,
              visible: object.visible,
              to: object.to,
              cc: object.cc,
              audience: object.audience
            )
            object.assign(published: time)
            activity.assign(published: time)
            activity.save
            OutboxActivityProcessor.process(account, activity)
          end
        end
      end
    end
  end
end
