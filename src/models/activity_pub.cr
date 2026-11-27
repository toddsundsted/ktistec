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

  # Returns the instance or builds a new one.
  #
  private def self.find_or_build(base : B.class, clazz : C.class, iri, attrs) forall B, C
    if (found = base.find?(iri, include_deleted: true, include_undone: true))
      return found if found.responds_to?(:deleted?) && found.deleted?
      return found if found.responds_to?(:undone?) && found.undone?
      found.assign(attrs)
    else
      clazz.new(attrs)
    end
  end

  # Returns the string value of the JSON-LD keyword `key`, if present.
  #
  private def self.keyword?(json, key)
    if (value = json[key]?)
      value.as_s? || raise Ktistec::JSON_LD::Error.new("#{key} is not a string")
    end
  end

  # Note: Take care when modifying this method. In particular,
  # avoid calling `map` on a subclass directly unless the subclass
  # explicitly defines it!

  def self.from_json_ld(json, **options)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    type = keyword?(json, "@type").try(&.split("#").last)
    iri = keyword?(json, "@id")
    {% begin %}
      case type
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
          find_or_build({{includer}}, {{subclass}}, iri, attrs)
        {% end %}
      {% end %}
      else
        if (default = options[:default]?)
          attrs = default.map(json, **options)
          find_or_build(default, default, iri, attrs)
        elsif (type = json["@type"]?)
          raise NotImplementedError.new(type.as_s)
        else
          raise NotImplementedError.new("no type")
        end
      end
    {% end %}
  end

  # the following method wraps the method above and ensures that the
  # returned instance is of the correct type

  macro included
    def self.from_json_ld(json, **options)
      instance = ActivityPub.from_json_ld(json, **options.merge(default: self))
      instance.as?(self) || raise ::Ktistec::JSON_LD::Error.new("#{instance.class} is not a #{self}")
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
