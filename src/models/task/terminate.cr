require "../task"
require "./deliver"
require "../activity_pub/actor"
require "../activity_pub/object"

class Task
  class Terminate < Task
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

    def perform
      if (object = subject.objects.first?)
        Log.info { "Task::Terminate: deleting #{object.iri} published=#{!!object.published}" }
        self.next_attempt_at = 30.seconds.from_now
        if object.published
          Task::Deliver.new(
            sender: subject,
            activity: object.make_delete_activity
          ).schedule
        end
        object.delete
      else
        Log.info { "Task::Terminate: deleting #{subject.iri}" }
        Task::Deliver.new(
          sender: subject,
          activity: subject.make_delete_activity
        ).schedule
        subject.delete
      end
    end
  end
end
