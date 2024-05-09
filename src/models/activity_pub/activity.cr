require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"

require "../../views/view_helper"

module ActivityModelRenderer
  include Ktistec::ViewHelper

  def self.to_json_ld(activity, recursive)
    render "src/views/activities/activity.json.ecr"
  end
end

module ActivityPub
  class Activity
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include Ktistec::Model::Serialized
    include Ktistec::Model::Polymorphic
    include Ktistec::Model::Undoable
    include ActivityPub

    @@table_name = "activities"

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

    @@recursive : Symbol | Bool = :default

    def to_json_ld(recursive = @@recursive)
      ActivityModelRenderer.to_json_ld(self, recursive)
    end

    def from_json_ld(json)
      self.assign(self.class.map(json))
    end

    def self.map(json : JSON::Any | String | IO, **options)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        "iri" => json.dig?("@id").try(&.as_s),
        "_type" => json.dig?("@type").try(&.as_s.split("#").last),
        "published" => (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
        # either pick up the actor's id or the embedded actor
        "actor_iri" => json.dig?("https://www.w3.org/ns/activitystreams#actor").try(&.as_s?),
        "actor" => if (actor = json.dig?("https://www.w3.org/ns/activitystreams#actor")) && actor.as_h?
          ActivityPub.from_json_ld(actor)
        end,
        # either pick up the object's id or the embedded object
        "object_iri" => json.dig?("https://www.w3.org/ns/activitystreams#object").try(&.as_s?),
        "object" => if (object = json.dig?("https://www.w3.org/ns/activitystreams#object")) && object.as_h?
          ActivityPub.from_json_ld(object)
        end,
        # either pick up the target's id or the embedded target
        "target_iri" => json.dig?("https://www.w3.org/ns/activitystreams#target").try(&.as_s?),
        "target" => if (target = json.dig?("https://www.w3.org/ns/activitystreams#target")) && target.as_h?
          ActivityPub.from_json_ld(target)
        end,
        "to" => to = dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
        "cc" => cc = dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
        "summary" => dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
        # use addressing to establish visibility
        "visible" => [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public")
      }.compact
    end
  end
end
