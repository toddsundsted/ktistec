require "json"

require "../../framework/json_ld"
require "../../framework/ext/sqlite3"
require "../../framework/model"
require "../../framework/model/common"
require "../../framework/util"
require "../activity_pub"

require "../../views/view_helper"

module ActivityPub
  class Collection
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include ActivityPub

    @@table_name = "collections"

    ALIASES = [
      "ActivityPub::CollectionPage",
      "ActivityPub::OrderedCollection",
      "ActivityPub::OrderedCollectionPage",
    ]

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

    # Allows same-origin matching for collections.
    #
    def iri_matches?(requested_iri : String) : Bool
      Ktistec::Util.same_origin?(self.iri, requested_iri)
    end

    def to_json_ld(recursive = true)
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

      def self.to_json_ld(collection, recursive)
        render "src/views/collections/collection.json.ecr"
      end

      def self.from_json_ld(json : JSON::Any | String | IO)
        json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
        collection_iri = json.dig?("@id").try(&.as_s?)
        {
          "iri"        => json.dig?("@id").try(&.as_s),
          "items_iris" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#items"),
          "items"      => if (items = json.dig?("https://www.w3.org/ns/activitystreams#items"))
            map_items(items, collection_iri)
          end,
          "total_items" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#totalItems", as: Int64),
          # pick up the collection's id and the embedded collection if origins match or anonymous
          "first_iri" => if (first = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#first"))
            first.as_s? || first.dig?("@id").try(&.as_s?)
          end,
          "first" => if first && first.as_h?
            if (first_iri = first.dig?("@id").try(&.as_s?))
              if Ktistec::Util.same_origin?(first_iri, collection_iri)
                ActivityPub::Collection.from_json_ld(first)
              end
            else
              ActivityPub::Collection.from_json_ld(first)
            end
          end,
          # pick up the collection's id and the embedded collection if origins match or anonymous
          "last_iri" => if (last = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#last"))
            last.as_s? || last.dig?("@id").try(&.as_s?)
          end,
          "last" => if last && last.as_h?
            if (last_iri = last.dig?("@id").try(&.as_s?))
              if Ktistec::Util.same_origin?(last_iri, collection_iri)
                ActivityPub::Collection.from_json_ld(last)
              end
            else
              ActivityPub::Collection.from_json_ld(last)
            end
          end,
          # pick up the collection's id and the embedded collection if origins match or anonymous
          "prev_iri" => if (prev = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#prev"))
            prev.as_s? || prev.dig?("@id").try(&.as_s?)
          end,
          "prev" => if prev && prev.as_h?
            if (prev_iri = prev.dig?("@id").try(&.as_s?))
              if Ktistec::Util.same_origin?(prev_iri, collection_iri)
                ActivityPub::Collection.from_json_ld(prev)
              end
            else
              ActivityPub::Collection.from_json_ld(prev)
            end
          end,
          # pick up the collection's id and the embedded collection if origins match or anonymous
          "next_iri" => if (_next = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#next"))
            _next.as_s? || _next.dig?("@id").try(&.as_s?)
          end,
          "next" => if _next && _next.as_h?
            if (next_iri = _next.dig?("@id").try(&.as_s?))
              if Ktistec::Util.same_origin?(next_iri, collection_iri)
                ActivityPub::Collection.from_json_ld(_next)
              end
            else
              ActivityPub::Collection.from_json_ld(_next)
            end
          end,
          # pick up the collection's id and the embedded collection if origins match or anonymous
          "current_iri" => if (current = Ktistec::JSON_LD.dig_first?(json, "https://www.w3.org/ns/activitystreams#current"))
            current.as_s? || current.dig?("@id").try(&.as_s?)
          end,
          "current" => if current && current.as_h?
            if (current_iri = current.dig?("@id").try(&.as_s?))
              if Ktistec::Util.same_origin?(current_iri, collection_iri)
                ActivityPub::Collection.from_json_ld(current)
              end
            else
              ActivityPub::Collection.from_json_ld(current)
            end
          end,
        }.compact
      end

      private def self.map_items(items, collection_iri)
        ([] of ActivityPub | String).tap do |array|
          items.as_a.each do |item|
            if item.as_s?
              array << item.as_s
            elsif item.as_h?
              if (item_id = item.dig?("@id").try(&.as_s?))
                if Ktistec::Util.same_origin?(item_id, collection_iri)
                  array << ActivityPub.from_json_ld(item)
                else
                  array << item_id
                end
              end
            else
              raise TypeCastError.new("unsupported JSON type")
            end
          end
        end
      end
    end
  end
end
