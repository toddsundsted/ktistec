require "json"

require "../framework/json_ld"

module ActivityPub
  def self.from_json_ld(json, **options)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {% begin %}
      case json["@type"]?.try(&.as_s.split("#").last)
      {% for subclass in @type.constants.reduce([] of TypeNode) { |a, t| a + @type.constant(t).all_subclasses << t } %}
        when {{name = subclass.stringify.split("::").last}}
          {% id = name.downcase.id %}
          {{id}} = {{subclass}}.find?(json["@id"]?.try(&.as_s)) || {{subclass}}.new
          {{id}}.assign(**{{subclass}}.map(json, **options))
      {% end %}
      else
        if (default = options[:default]?)
          instance = default.find?(json["@id"]?.try(&.as_s)) || default.new
          instance.assign(**default.map(json, **options))
          return instance
        end
        if (type = json["@type"]?)
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
end
