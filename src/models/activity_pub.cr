require "json"

require "../framework/json_ld"
require "../framework/model"
require "./activity_pub/mixins/blockable"
require "./activity_pub/mixins/linked"

# An ActivityPub model.
#
# This module indicates that an including model is an ActivityPub
# model. It defines class methods for instantiating ActivityPub models
# from JSON-LD.
#
module ActivityPub
  # the only logging in this module is related to mapping JSON-LD.
  Log = ::Log.for("ktistec.json_ld")

  # Note: Take care when modifying this method. In particular,
  # avoid calling `map` on a subclass directly unless the subclass
  # explicitly defines it!

  def self.from_json_ld(json, **options)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {% begin %}
      case (type = json["@type"]?.try(&.as_s.split("#").last))
      {% for includer in @type.includers %}
        {% for subclass in includer.all_subclasses << includer %}
          {% name = subclass.stringify.split("::").last %}
          {% if subclass == includer && includer.has_constant?(:ALIASES) %}
            {% aliases = [name] + includer.constant(:ALIASES).map(&.split("::").last) %}
            when {{aliases.map(&.stringify).join(",").id}}
          {% else %}
            when {{name}}
          {% end %}
          {% if subclass.class.methods.map(&.name).includes?("map".id) %}
            attrs = {{subclass}}.map(json, **options)
          {% else %}
            attrs = {{includer}}.map(json, **options)
          {% end %}
          if type == {{name}}
            attrs["type"] = {{subclass.stringify}}
          else
            attrs["type"] = "{{includer}}::#{type}"
          end
          {{subclass}}.find?(json["@id"]?.try(&.as_s)).try(&.assign(attrs)) ||
            {{subclass}}.new(attrs)
        {% end %}
      {% end %}
      else
        if (default = options[:default]?)
          attrs = default.map(json, **options)
          default.find?(json["@id"]?.try(&.as_s)).try(&.assign(attrs)) ||
            default.new(attrs)
        elsif (type = json["@type"]?)
          raise NotImplementedError.new(type.as_s)
        else
          raise NotImplementedError.new("no type")
        end
      end
    {% end %}
  end

  def self.from_json_ld?(json, **options)
    from_json_ld(json, **options)
  rescue ex : NotImplementedError | TypeCastError
    Log.debug { ex.message }
  end

  # the following methods wrap the methods above and ensure that the
  # returned instance is of the correct type

  macro included
    def self.from_json_ld(json, **options)
      ActivityPub.from_json_ld(json, **options.merge(default: self)).as(self)
    end

    def self.from_json_ld?(json, **options)
      ActivityPub.from_json_ld?(json, **options.merge(default: self)).as(self?)
    end
  end

  # Helpers

  # Digs out a natural-language string value.
  #
  # ActivityStreams natural-language properties may be sent as a plain
  # string, a language map, or an expanded value object.
  #
  def self.dig_text?(json : JSON::Any, *selector) : String?
    if (value = Ktistec::JSON_LD.dig_first?(json, *selector))
      if (hash = value.as_h?)
        if (text = hash["@value"]?)
          text.as_s?
        else
          (hash["und"]? || hash.first_value?).try(&.as_s?)
        end
      else
        value.as_s?
      end
    end
  end

  # Adds common filters to a query.
  #
  macro common_filters(**options)
    <<-FILTERS
      {% if (key = options[:objects]) %}
        AND {{key.id}}.special is NULL
        AND {{key.id}}.deleted_at is NULL
        AND {{key.id}}.blocked_at is NULL
      {% end %}
      {% if (key = options[:actors]) %}
        AND {{key.id}}.deleted_at IS NULL
        AND {{key.id}}.blocked_at IS NULL
      {% end %}
      {% if (key = options[:activities]) %}
        AND {{key.id}}.undone_at IS NULL
      {% end %}
    FILTERS
  end
end
