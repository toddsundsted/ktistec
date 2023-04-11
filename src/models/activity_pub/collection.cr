require "json"

require "../../framework/json_ld"
require "../../framework/ext/sqlite3"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"

require "../../views/view_helper"

module CollectionModelRenderer
  include Ktistec::ViewHelper

  def self.to_json_ld(collection, recursive)
    render "src/views/collections/collection.json.ecr"
  end
end

module ActivityPub
  class Collection
    include Ktistec::Model(Common, Linked, Serialized)
    include ActivityPub

    @@table_name = "collections"

    @[Persistent]
    property items_iris : Array(String)?

    @[Assignable]
    property items : Array(ActivityPub | String)?

    @[Persistent]
    property total_items : Int64?

    @[Persistent]
    property first_iri : String?

    @[Assignable]
    property first : Collection?

    @[Persistent]
    property last_iri : String?

    @[Assignable]
    property last : Collection?

    @[Persistent]
    property prev_iri : String?

    @[Assignable]
    property prev : Collection?

    @[Persistent]
    property next_iri : String?

    @[Assignable]
    property next : Collection?

    @[Persistent]
    property current_iri : String?

    @[Assignable]
    property current : Collection?

    def to_json_ld(recursive = true)
      CollectionModelRenderer.to_json_ld(self, recursive)
    end

    def from_json_ld(json)
      self.assign(self.class.map(json))
    end

    private def self.map_items(items)
      ([] of ActivityPub | String).tap do |array|
        items.as_a.each do |item|
          if item.as_s?
            array << item.as_s
          elsif item.as_h?
            array << ActivityPub.from_json_ld(item)
          else
            raise TypeCastError.new("unsupported JSON type")
          end
        end
      end
    end

    def self.map(json : JSON::Any | String | IO, **options)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        "iri" => json.dig?("@id").try(&.as_s),
        "items_iris" => dig_ids?(json, "https://www.w3.org/ns/activitystreams#items"),
        "items" => if (items = json.dig?("https://www.w3.org/ns/activitystreams#items"))
          map_items(items)
        end,
        "total_items" => json.dig?("https://www.w3.org/ns/activitystreams#totalItems").try(&.as_i64),
        # pick up the collection's id or the embedded collection
        "first_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#first"),
        "first" => if (first = json.dig?("https://www.w3.org/ns/activitystreams#first")) && first.as_h?
          Collection.from_json_ld(first)
        end,
        # pick up the collection's id or the embedded collection
        "last_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#last"),
        "last" => if (last = json.dig?("https://www.w3.org/ns/activitystreams#last")) && last.as_h?
          Collection.from_json_ld(last)
        end,
        # pick up the collection's id or the embedded collection
        "prev_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#prev"),
        "prev" => if (prev = json.dig?("https://www.w3.org/ns/activitystreams#prev")) && prev.as_h?
          Collection.from_json_ld(prev)
        end,
        # pick up the collection's id or the embedded collection
        "next_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#next"),
        "next" => if (_next = json.dig?("https://www.w3.org/ns/activitystreams#next")) && _next.as_h?
          Collection.from_json_ld(_next)
        end,
        # pick up the collection's id or the embedded collection
        "current_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#current"),
        "current" => if (current = json.dig?("https://www.w3.org/ns/activitystreams#current")) && current.as_h?
          Collection.from_json_ld(current)
        end
      }.compact
    end
  end
end
