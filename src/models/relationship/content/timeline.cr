require "../../../framework/topic"
require "../../relationship"
require "../../activity_pub/actor"
require "../../activity_pub/object"

class Relationship
  class Content
    # Abstract base for the materialized timeline views.
    #
    abstract class Timeline < Relationship
      belongs_to owner, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(owner) { "missing: #{from_iri}" unless owner? }

      belongs_to object, class_name: ActivityPub::Object, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }

      # Returns the concrete timeline subtypes as a sorted,
      # single-quoted, comma-separated SQL list.
      #
      # This is the source for the `type IN (...)` list the timeline
      # read query interpolates. It must stay byte-for-byte identical
      # to the predicate of the partial index
      # `idx_relationships_timeline_from_iri_created_at` so the index
      # binds.
      #
      def self.type_in_list : String
        {% begin %}
          {% leaves = @type.all_subclasses.reject(&.abstract?).map(&.stringify).sort %}
          {{leaves.map { |type| "'#{type.id}'" }.join(",")}}
        {% end %}
      end

      property confirmed : Bool { true }

      def after_save
        Ktistec::Topic{"/actors/#{owner.username}/timeline"}.notify_subscribers
      end
    end
  end
end
