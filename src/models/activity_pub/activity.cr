require "../../framework/model"

module ActivityPub
  class Activity
    include Balloon::Model(Common, Polymorphic, Serialized)

    @@table_name = "activities"

    def self.find(_iri iri : String?)
      find(iri: iri)
    end

    def self.find?(_iri iri : String?)
      find?(iri: iri)
    end

    @[Persistent]
    property iri : String { "" }
    validates(iri) { unique_absolute_uri?(iri) }

    private def unique_absolute_uri?(iri)
      if iri.blank?
        "must be present"
      elsif !URI.parse(iri).absolute?
        "must be an absolute URI"
      elsif (activity = Activity.find?(iri)) && activity.id != self.id
        "must be unique"
      end
    end

    def local
      iri.starts_with?(Balloon.host)
    end

    @[Persistent]
    property visible : Bool { false }
    validates(visible) do
      "may not be true" unless !visible || local
    end

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

    def to_json_ld(recursive = false)
      activity = self
      render "src/views/activities/activity.json.ecr"
    end

    def self.from_json_ld(json)
      attrs = map(json)
      {% begin %}
        case attrs[:_type]
        {% for subclass in @type.all_subclasses %}
          when {{subclass.stringify.split("::").last}}
            {{subclass}}.new(**attrs)
        {% end %}
        else
          self.new(**attrs)
        end
      {% end %}
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json)
      json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
      {
        iri: json.dig?("@id").try(&.as_s),
        _type: json.dig?("@type").try(&.as_s.split("#").last),
        published: (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
        actor_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#actor"),
        object_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#object"),
        target_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#target"),
        to: dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
        cc: dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
        summary: dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und")
      }
    end
  end
end
