require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"

require "../../views/view_helper"

module ActivityPub
  class Activity
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include Ktistec::Model::Polymorphic
    include Ktistec::Model::Undoable
    include ActivityPub

    @@table_name = "activities"

    ALIASES = [
      "ActivityPub::Activity::Add",
      "ActivityPub::Activity::Block",
      "ActivityPub::Activity::Flag",
      "ActivityPub::Activity::Listen",
      "ActivityPub::Activity::Read",
      "ActivityPub::Activity::Remove",
      "ActivityPub::Activity::View",
    ]

    @[Persistent]
    property visible : Bool { false }

    @[Persistent]
    property published : Time?

    @[Persistent]
    property actor_iri : String?
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri

    class ObjectActivity < Activity
      belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
    end

    @[Persistent]
    property object_iri : String?

    @[Persistent]
    property target_iri : String?

    @[Persistent]
    property to : Array(String)?

    @[Persistent]
    property cc : Array(String)?

    @[Persistent]
    property audience : Array(String)?

    @[Persistent]
    property summary : String?

    def display_date(timezone = nil)
      date(timezone).to_s("%l:%M%p · %b %-d, %Y").lstrip(' ')
    end

    def short_date(timezone = nil)
      (date = self.date(timezone)) < 1.day.ago ? date.to_s("%b %-d, %Y").lstrip(' ') : date.to_s("%l:%M%p").lstrip(' ')
    end

    private def date(timezone)
      timezone ||= Time::Location.local
      (published || created_at).in(timezone)
    end

    class_getter recursive : Symbol | Bool = :default

    def to_json_ld(recursive = self.class.recursive)
      ModelHelper.to_json_ld(self, recursive)
    end

    def from_json_ld(json)
      self.assign(self.class.map(json))
    end

    def self.map(json, **options)
      ModelHelper.from_json_ld(json)
    end

    module ModelHelper
      include Ktistec::ViewHelper

      def self.to_json_ld(activity, recursive)
        render "src/views/activities/activity.json.ecr"
      end

      def self.from_json_ld(json : JSON::Any | String | IO)
        json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
        activity_host = (activity_iri = json.dig?("@id").try(&.as_s?)) ? parse_host(activity_iri) : nil
        {
          "iri"       => json.dig?("@id").try(&.as_s),
          "_type"     => json.dig?("@type").try(&.as_s.split("#").last),
          "published" => (p = Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
          # pick up the actor's id and the embedded actor if the hosts match
          "actor_iri" => if (actor = json.dig?("https://www.w3.org/ns/activitystreams#actor"))
            actor.as_s? || actor.dig?("@id").try(&.as_s?)
          end,
          "actor" => if actor && actor.as_h?
            if (actor_iri = actor.dig?("@id").try(&.as_s?)) && activity_host && parse_host(actor_iri) == activity_host
              ActivityPub.from_json_ld(actor, default: ActivityPub::Actor)
            end
          end,
          # pick up the object's id and the embedded object if the hosts match
          "object_iri" => if (object = json.dig?("https://www.w3.org/ns/activitystreams#object"))
            object.as_s? || object.dig?("@id").try(&.as_s?)
          end,
          "object" => if object && object.as_h?
            if (object_iri = object.dig?("@id").try(&.as_s?)) && activity_host && parse_host(object_iri) == activity_host
              ActivityPub.from_json_ld(object, default: ActivityPub::Object)
            end
          end,
          # pick up the target's id and the embedded target if the hosts match
          "target_iri" => if (target = json.dig?("https://www.w3.org/ns/activitystreams#target"))
            target.as_s? || target.dig?("@id").try(&.as_s?)
          end,
          "target" => if target && target.as_h?
            if (target_iri = target.dig?("@id").try(&.as_s?)) && activity_host && parse_host(target_iri) == activity_host
              ActivityPub.from_json_ld(target, default: ActivityPub::Object)
            end
          end,
          "to"       => to = Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
          "cc"       => cc = Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
          "audience" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#audience"),
          "summary"  => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
          # use addressing to establish visibility
          "visible" => [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public"),
        }.compact
      end

      private def self.parse_host(uri)
        URI.parse(uri).host
      rescue URI::Error
      end
    end
  end
end
