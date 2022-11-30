require "json"

require "../framework/json_ld"
require "../framework/model"
require "./activity_pub/mixins/*"

module ActivityPub
  def self.from_json_ld(json, **options)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {% begin %}
      case json["@type"]?.try(&.as_s.split("#").last)
      {% for subclass in @type.includers.reduce([] of TypeNode) { |a, t| a + t.all_subclasses << t }.uniq %}
        when {{name = subclass.stringify.split("::").last}}
          {% id = name.downcase.id %}
          attrs = {{subclass}}.map(json, **options)
          {{subclass}}.find?(json["@id"]?.try(&.as_s)).try(&.assign(attrs)) ||
            {{subclass}}.new(attrs)
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
  rescue NotImplementedError
    nil
  end

  macro included
    def self.from_json_ld(json, **options)
      ActivityPub.from_json_ld(json, **options.merge({default: self})).as(self)
    end

    def self.from_json_ld?(json, **options)
      ActivityPub.from_json_ld?(json, **options.merge({default: self})).as(self?)
    rescue TypeCastError
    end
  end
end
