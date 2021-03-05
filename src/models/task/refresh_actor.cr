require "../task"
require "../activity_pub/actor"

class Task
  class RefreshActor < Task
    private EXISTS_QUERY = "subject_iri = ? AND complete = 0 AND backtrace IS NULL"

    belongs_to source, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(source) { "missing: #{source_iri}" unless source? }

    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: subject_iri, primary_key: iri
    validates(actor) do
      if actor?.nil?
        "missing: #{subject_iri}"
      elsif actor.local?
        "local: #{subject_iri}"
      elsif !(instances = self.class.where(EXISTS_QUERY, subject_iri)).empty? && instances.any? { |instance| instance.id != self.id }
        "scheduled: #{subject_iri}"
      end
    end

    def self.exists?(iri)
      !where(EXISTS_QUERY, iri).empty?
    end

    def perform
      if (instance = ActivityPub::Actor.dereference?(actor.iri, ignore_cached: true))
        instance.save
      else
        message = "failed to dereference #{actor.iri}"
        failures << Failure.new(message)
        Log.info { message }
      end
    end
  end
end
