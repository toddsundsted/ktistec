require "json"

module ActivityPub
  def self.from_json_ld(json)
    json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {% begin %}
      case json["@type"].as_s.split("#").last
      {% for subclass in @type.constants.reduce([] of TypeNode) { |a, t| a + @type.constant(t).all_subclasses << t } %}
        when {{name = subclass.stringify.split("::").last}}
          {% id = name.downcase.id %}
          {{id}} = {{subclass}}.find?(json["@id"]?.try(&.as_s)) || {{subclass}}.new
          {{id}}.assign(**{{subclass}}.map(json))
      {% end %}
      else
        raise NotImplementedError.new(json["@type"].as_s)
      end
    {% end %}
  end
end
