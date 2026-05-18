require "../task"
require "../account"
require "../activity_pub/actor"
require "../activity_pub/object"
require "../../services/outbox_activity_processor"

class Task
  class Terminate < Task
    Log = ::Log.for(self)

    belongs_to source, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(source) { "missing: #{source_iri}" unless source? }

    belongs_to subject, class_name: ActivityPub::Actor, foreign_key: subject_iri, primary_key: iri
    validates(subject) do
      if subject?.nil?
        "missing: #{subject_iri}"
      elsif subject.cached?
        "remote: #{subject_iri}"
      end
    end

    # deletion is a visibility concern that doesn't apply here.

    def subject
      @subject ||= ActivityPub::Actor.find(iri: subject_iri, include_deleted: true)
    end

    def perform
      actor = subject
      account = Account.find?(iri: actor.iri)
      if (object = actor.objects.first?)
        self.next_attempt_at = 30.seconds.from_now
        Log.warn { "Task::Terminate: deleting #{object.iri}" }
        if account && object.published
          OutboxActivityProcessor.process(account, object.make_delete_activity.save)
        else
          object.delete!
        end
      elsif account && !actor.deleted?
        Log.warn { "Task::Terminate: deleting #{actor.iri}" }
        OutboxActivityProcessor.process(account, actor.make_delete_activity.save)
        account.destroy
      else
        actor.delete! unless actor.deleted?
        account.try(&.destroy)
      end
    end
  end
end
