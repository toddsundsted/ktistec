require "json"

require "../framework/json_ld"

module ActivityPub
  def self.from_named_tuple(*, _prefix prefix : String = "", **options)
    {% begin %}
      key = prefix + "type"
      case options[key]?
      {% for subclass in @type.constants.reduce([] of TypeNode) { |a, t| a + @type.constant(t).all_subclasses << @type.constant(t) } %}
        when {{name = subclass.stringify}}
          {% id = name.split("::").last.downcase.id %}
          attrs = options.merge({_prefix: prefix})
          {{id}} = {{subclass}}.find?(options["iri"]?).try(&.assign(**attrs)) ||
            {{subclass}}.new(**attrs)
          return {{id}}
      {% end %}
      else
        if (default = options[:default]?)
          attrs = options.merge({_prefix: prefix})
          instance = default.find?(options["iri"]?).try(&.assign(**attrs)) ||
            default.new(**attrs)
          return instance
        end
        if (type = options[key]?)
          raise NotImplementedError.new(type.to_s)
        else
          raise NotImplementedError.new("no type")
        end
      end
    {% end %}
  end

  def self.from_named_tuple?(*, _prefix prefix : String = "", **options)
    from_named_tuple(**options.merge({_prefix: prefix}))
  rescue NotImplementedError
    nil
  end

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
