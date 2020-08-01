require "../../framework/model"
require "json"

module ActivityPub
  class Collection
    include Balloon::Model(Common)

    @@table_name = "collections"

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
      elsif (collection = Collection.find?(iri)) && collection.id != self.id
        "must be unique"
      end
    end

    def local
      iri.starts_with?(Balloon.host)
    end

    @[Persistent]
    property items_json : String?
    serializes items, class_name: Array(String)

    @[Assignable]
    @items_cached : Array(JSON::Any)?

    def items_cached=(@items_cached : Array(JSON::Any)) : Array(JSON::Any)
      unless items_cached.empty?
        if items_cached[0].as_s?
          self.items = items_cached.map(&.as_s)
        elsif items_cached[0].as_h?
          self.items = items_cached.map(&.dig("@id").as_s)
        end
      end
      items_cached
    end

    def items_cached
      items_cached.map do |item|
        yield item
      end
    end

    def items_cached
      @items_cached.not_nil!
    end

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

    def self.from_json_ld(json)
      new(**map(json))
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json, **options)
      json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
      {
        iri: json.dig?("@id").try(&.as_s),
        items_cached: json.dig?("https://www.w3.org/ns/activitystreams#items").try(&.as_a),
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
