require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/common"
require "../../framework/util"
require "../activity_pub"

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
    property instrument_iri : String?

    @[Persistent]
    property result_iri : String?

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
  end
end

require "../../views/view_helper"

module ActivityPub
  class Activity
    module ModelHelper
      include Ktistec::ViewHelper

      def self.to_json_ld(activity, recursive)
        render "src/views/activities/activity.json.ecr"
      end

      MAY_EMBED_OBJECT = [
        "https://www.w3.org/ns/activitystreams#Create",
        "https://www.w3.org/ns/activitystreams#Update",
      ]

      def self.from_json_ld(json : JSON::Any | String | IO)
        json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
        may_embed_object = json.dig?("@type").try(&.as_s?).in?(MAY_EMBED_OBJECT)
        activity_origin = Ktistec::Util.origin?(json.dig?("@id").try(&.as_s?))
        actor_origin = Ktistec::Util.origin?(Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#actor"))
        {
          "iri"       => json.dig?("@id").try(&.as_s),
          "_type"     => json.dig?("@type").try(&.as_s.split("#").last),
          "published" => Ktistec::JSON_LD.dig_time?(json, "https://www.w3.org/ns/activitystreams#published"),
          # pick up the actor's id and the embedded actor if the origins match
          "actor_iri" => if (actor = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#actor"))
            actor.as_s? || actor.dig?("@id").try(&.as_s?)
          end,
          "actor" => if actor && actor.as_h?
            if anchored?(actor.dig?("@id").try(&.as_s?), activity_origin, actor_origin)
              ActivityPub.from_json_ld(actor, default: ActivityPub::Actor)
            end
          end,
          # pick up the object's id and the embedded object if the origins match
          "object_iri" => if (object = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#object"))
            object.as_s? || object.dig?("@id").try(&.as_s?)
          end,
          "object" => if may_embed_object && object && object.as_h?
            if anchored?(object.dig?("@id").try(&.as_s?), activity_origin, actor_origin)
              ActivityPub.from_json_ld(object, default: ActivityPub::Object)
            end
          end,
          # pick up the target's id and the embedded target if the origins match
          "target_iri" => if (target = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#target"))
            target.as_s? || target.dig?("@id").try(&.as_s?)
          end,
          "target" => if target && target.as_h?
            if anchored?(target.dig?("@id").try(&.as_s?), activity_origin, actor_origin)
              ActivityPub.from_json_ld(target, default: ActivityPub::Object)
            end
          end,
          # pick up the instrument's id and the embedded instrument if the origins match
          "instrument_iri" => if (instrument = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#instrument"))
            instrument.as_s? || instrument.dig?("@id").try(&.as_s?)
          end,
          "instrument" => if instrument && instrument.as_h?
            if anchored?(instrument.dig?("@id").try(&.as_s?), activity_origin, actor_origin)
              ActivityPub.from_json_ld(instrument, default: ActivityPub::Object)
            end
          end,
          # pick up the result's id and the embedded result if the origins match
          "result_iri" => if (result = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#result"))
            result.as_s? || result.dig?("@id").try(&.as_s?)
          end,
          "result" => if result && result.as_h?
            if anchored?(result.dig?("@id").try(&.as_s?), activity_origin, actor_origin)
              ActivityPub.from_json_ld(result, default: ActivityPub::Object)
            end
          end,
          "to"       => to = Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
          "cc"       => cc = Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
          "audience" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#audience"),
          "summary"  => ActivityPub.dig_text?(json, "https://www.w3.org/ns/activitystreams#summary"),
          # use addressing to establish visibility
          "visible" => [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public"),
        }.compact
      end

      # Returns true if the node's origin matches the origins of both
      # the activity and its actor.
      #
      private def self.anchored?(iri : String?, activity_origin : String?, actor_origin : String?) : Bool
        origin = Ktistec::Util.origin?(iri)
        !origin.nil? && origin == activity_origin && origin == actor_origin
      end
    end
  end
end
