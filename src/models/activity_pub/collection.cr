require "json"

require "../../framework/json_ld"
require "../../framework/ext/sqlite3"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"

require "../../views/view_helper"

module ActivityPub
  class Collection
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include ActivityPub

    @@table_name = "collections"

    @@required_iri = false

    @[Persistent]
    property items_iris : Array(String)?

    @[Assignable]
    property items : Array(ActivityPub | String)?

    @[Persistent]
    property total_items : Int64?

    @[Persistent]
    property first_iri : String?
    belongs_to :first, class_name: {{@type}}, foreign_key: first_iri, primary_key: iri

    @[Persistent]
    property last_iri : String?
    belongs_to :last, class_name: {{@type}}, foreign_key: last_iri, primary_key: iri

    @[Persistent]
    property prev_iri : String?
    belongs_to :prev, class_name: {{@type}}, foreign_key: prev_iri, primary_key: iri

    @[Persistent]
    property next_iri : String?
    belongs_to :next, class_name: {{@type}}, foreign_key: next_iri, primary_key: iri

    @[Persistent]
    property current_iri : String?
    belongs_to :current, class_name: {{@type}}, foreign_key: current_iri, primary_key: iri

    # Traverses the collection and returns IRIs of all items.
    #
    # Returns `nil` if `items_iris`, `first_iri` and `last_iri` are
    # all `nil`. This is how ActivityPub hashtag collections on
    # Mastodon are represented -- the items are retrieved via the
    # Mastodon API.
    #
    def all_item_iris(source, maximum_depth = 10)
      items_iris || begin
        if (first = self.first?(source, dereference: true))
          Array(String).new.tap do |items|
            if (iris = first.items_iris)
              items.concat(iris)
            end
            collection = first
            maximum_depth.times do # cap depth
              if (temporary = collection.next?(source, dereference: true))
                if (iris = temporary.items_iris)
                  items.concat(iris)
                end
                collection = temporary
              else
                break
              end
            end
          end
        elsif (last = self.last?(source, dereference: true))
          Array(String).new.tap do |items|
            if (iris = last.items_iris)
              items.concat(iris)
            end
            collection = last
            maximum_depth.times do # cap depth
              if (temporary = collection.prev?(source, dereference: true))
                if (iris = temporary.items_iris)
                  items.concat(iris)
                end
                collection = temporary
              else
                break
              end
            end
          end
        end
      end
    end

    def to_json_ld(recursive = true)
      CollectionModelHelper.to_json_ld(self, recursive)
    end

    def from_json_ld(json)
      self.assign(CollectionModelHelper.from_json_ld(json))
    end

    def self.map(json, **options)
      CollectionModelHelper.from_json_ld(json)
    end
  end
end

private module CollectionModelHelper
  include Ktistec::ViewHelper

  def self.to_json_ld(collection, recursive)
    render "src/views/collections/collection.json.ecr"
  end

  def self.from_json_ld(json : JSON::Any | String | IO)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {
      "iri" => json.dig?("@id").try(&.as_s),
      "items_iris" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#items"),
      "items" => if (items = json.dig?("https://www.w3.org/ns/activitystreams#items"))
        map_items(items)
      end,
      "total_items" => json.dig?("https://www.w3.org/ns/activitystreams#totalItems").try(&.as_i64),
      # pick up the collection's id or the embedded collection
      "first_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#first"),
      "first" => if (first = json.dig?("https://www.w3.org/ns/activitystreams#first")) && first.as_h?
        ActivityPub::Collection.from_json_ld(first)
      end,
      # pick up the collection's id or the embedded collection
      "last_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#last"),
      "last" => if (last = json.dig?("https://www.w3.org/ns/activitystreams#last")) && last.as_h?
        ActivityPub::Collection.from_json_ld(last)
      end,
      # pick up the collection's id or the embedded collection
      "prev_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#prev"),
      "prev" => if (prev = json.dig?("https://www.w3.org/ns/activitystreams#prev")) && prev.as_h?
        ActivityPub::Collection.from_json_ld(prev)
      end,
      # pick up the collection's id or the embedded collection
      "next_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#next"),
      "next" => if (_next = json.dig?("https://www.w3.org/ns/activitystreams#next")) && _next.as_h?
        ActivityPub::Collection.from_json_ld(_next)
      end,
      # pick up the collection's id or the embedded collection
      "current_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#current"),
      "current" => if (current = json.dig?("https://www.w3.org/ns/activitystreams#current")) && current.as_h?
        ActivityPub::Collection.from_json_ld(current)
      end
    }.compact
  end

  def self.map_items(items)
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
end
