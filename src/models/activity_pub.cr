require "json"

require "../framework/json_ld"
require "../framework/model"
require "./activity_pub/mixins/*"

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
end
