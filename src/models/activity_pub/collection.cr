require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"

module ActivityPub
  class Collection
    include Ktistec::Model(Common, Linked, Serialized)
    include ActivityPub

    @@table_name = "collections"

    @[Persistent]
    property items_iris : Array(String)?

    @[Assignable]
    property items : Array(JSON::Any)?

    @[Persistent]
    property total_items : Int64?

    @[Persistent]
    property first : String?

    @[Persistent]
    property last : String?

    @[Persistent]
    property prev : String?

    @[Persistent]
    property next : String?

    @[Persistent]
    property current : String?

    def to_json_ld(recursive = false)
      collection = self
      render "src/views/collections/collection.json.ecr"
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json, **options)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
      {
        iri: json.dig?("@id").try(&.as_s),
        items_iris: dig_ids?(json, "https://www.w3.org/ns/activitystreams#items"),
        items: json.dig?("https://www.w3.org/ns/activitystreams#items").try(&.as_a),
        total_items: json.dig?("https://www.w3.org/ns/activitystreams#totalItems").try(&.as_i64),
        first: json.dig?("https://www.w3.org/ns/activitystreams#first").try(&.as_s),
        last: json.dig?("https://www.w3.org/ns/activitystreams#last").try(&.as_s),
        prev: json.dig?("https://www.w3.org/ns/activitystreams#prev").try(&.as_s),
        next: json.dig?("https://www.w3.org/ns/activitystreams#next").try(&.as_s),
        current: json.dig?("https://www.w3.org/ns/activitystreams#current").try(&.as_s)
      }
    end
  end
end
