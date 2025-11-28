require "../task"
require "../activity_pub/actor"
require "../activity_pub/object"
require "../activity_pub/collection"
require "../relationship/content/pin"

class Task
  class RefreshActor < Task
    Log = ::Log.for(self)

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

    class Failure
      include JSON::Serializable

      property description : String

      property timestamp : Time

      def initialize(@description, @timestamp = Time.utc)
      end
    end

    @[Persistent]
    @[Insignificant]
    property failures : Array(Failure) { [] of Failure }

    def perform
      if (instance = ActivityPub::Actor.dereference?(source, actor.iri, ignore_cached: true))
        instance.save.up!
        sync_featured_collection(instance)
        Ktistec::Topic{"/actor/refresh"}.notify_subscribers(actor.id.to_s)
      else
        actor.down!
        Ktistec::Topic{"/actor/refresh"}.notify_subscribers(actor.id.to_s)
        message = "failed to dereference #{actor.iri}"
        failures << Failure.new(message)
        Log.debug { message }
      end
    end

    private def sync_featured_collection(actor)
      unless actor.local?
        if (featured = actor.featured)
          if (collection = ActivityPub::Collection.dereference?(source, featured))
            if (object_iris = collection.all_item_iris(source))
              update_pins(actor, object_iris)
            end
          end
        end
      end
    end

    private def update_pins(actor, new_iris)
      new_iris_set = new_iris.to_set
      current_pins = Relationship::Content::Pin.where(actor: actor)
      current_iris_set = current_pins.map(&.to_iri).to_set
      current_pins.each do |pin|
        pin.destroy unless new_iris_set.includes?(pin.to_iri)
      end
      (new_iris_set - current_iris_set).each do |object_iri|
        if (object = ActivityPub::Object.dereference?(source, object_iri))
          pin = Relationship::Content::Pin.new(actor: actor, object: object)
          pin.save if pin.valid?  # saves the object, too
        end
      end
    end
  end
end
