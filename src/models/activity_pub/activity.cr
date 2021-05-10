require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"

module ActivityPub
  class Activity
    include Ktistec::Model(Common, Polymorphic, Serialized, Linked)
    include ActivityPub

    @@table_name = "activities"

    @[Persistent]
    property visible : Bool { false }

    @[Persistent]
    property published : Time?

    @[Persistent]
    property actor_iri : String?

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

    def display_date
      date.to_s("%l:%M%p · %b %-d, %Y").lstrip(' ')
    end

    def short_date
      date < 1.day.ago ? date.to_s("%b %-d, %Y").lstrip(' ') : date.to_s("%l:%M%p").lstrip(' ')
    end

    private def date
      (published || created_at).to_local
    end

    def to_json_ld(recursive = false)
      activity = self
      render "src/views/activities/activity.json.ecr"
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json, **options)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        iri: json.dig?("@id").try(&.as_s),
        _type: json.dig?("@type").try(&.as_s.split("#").last),
        published: (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
        # either pick up the actor's id or the embedded actor
        actor_iri: json.dig?("https://www.w3.org/ns/activitystreams#actor").try(&.as_s?),
        actor: if (actor = json.dig?("https://www.w3.org/ns/activitystreams#actor")) && actor.as_h?
          ActivityPub.from_json_ld(actor)
        end,
        # either pick up the object's id or the embedded object
        object_iri: json.dig?("https://www.w3.org/ns/activitystreams#object").try(&.as_s?),
        object: if (object = json.dig?("https://www.w3.org/ns/activitystreams#object")) && object.as_h?
          ActivityPub.from_json_ld(object)
        end,
        # either pick up the target's id or the embedded target
        target_iri: json.dig?("https://www.w3.org/ns/activitystreams#target").try(&.as_s?),
        target: if (target = json.dig?("https://www.w3.org/ns/activitystreams#target")) && target.as_h?
          ActivityPub.from_json_ld(target)
        end,
        to: to = dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
        cc: cc = dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
        summary: dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
        # use addressing to establish visibility
        visible: [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public")
      }
    end
  end
end
