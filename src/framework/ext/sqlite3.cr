require "json"
require "sqlite3"

private alias Supported = JSON::Serializable | Array(JSON::Serializable) | Array(String)

class SQLite3::ResultSet
  {% for type in Supported.union_types %}
    def read(type : {{type}}?.class)
      (json = read(String?)) ? type.from_json(json) : nil
    end
  {% end %}
end

class SQLite3::Statement
  {% for type in Supported.union_types %}
    private def bind_arg(index, value : {{type}}?)
      bind_arg(index, value.to_json)
    end
  {% end %}
end
