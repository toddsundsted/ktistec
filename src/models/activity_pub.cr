require "json"

module ActivityPub
  def self.from_json_ld(json)
    json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {% begin %}
      case json["@type"].as_s.split("#").last
      {% for subclass in @type.constants.reduce([] of TypeNode) { |a, t| a + @type.constant(t).all_subclasses << t } %}
        when {{subclass.stringify.split("::").last}}
          {{subclass}}.new(**{{subclass}}.map(json))
      {% end %}
      end
    {% end %}
  end
end
