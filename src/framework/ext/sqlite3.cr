require "json"
require "xml"
require "sqlite3"

if LibSQLite3.libversion < 3035000
  Log.fatal { "Ktistec requires SQLite3 version 3.35.0 or later" }
  exit -1
end

module DB
  abstract class Statement
    protected def emit_log(args : Enumerable)
      # override the library definition of `emit_log` to silence it.
    end
  end
end

{% if flag?(:"ktistec:experimental") %}
  require "benchmark"

  # See: https://www.sqlite.org/lang_analyze.html

  module SQLite3
    class Connection
      def do_close
        time = Benchmark.realtime { check LibSQLite3.exec(self, "PRAGMA analysis_limit=400; PRAGMA optimize;", nil, nil, nil) }
        Log.info { "Updating statistics: #{sprintf("%.3fms", time.total_milliseconds)}" }
      ensure
        previous_def
      end
    end
  end
{% end %}

private alias Supported = JSON::Serializable | Array(JSON::Serializable) | Array(String)

class SQLite3::ResultSet
  {% for type in Supported.union_types %}
    def read(type : {{type}}.class)
      (json = read(String)) ; type.from_json(json)
    end
    def read(type : {{type}}?.class)
      (json = read(String?)) ? type.from_json(json) : nil
    end
  {% end %}
end

class SQLite3::Statement
  {% for type in Supported.union_types %}
    private def bind_arg(index, value : {{type}})
      bind_arg(index, value.to_json)
    end
  {% end %}
end

lib LibSQLite3
  fun config = sqlite3_config(Int32, ...) : Code
  fun memory_used = sqlite3_memory_used() : Int64
  fun result_text = sqlite3_result_text(SQLite3Context, UInt8*, Int32, Void*) : Nil
  fun libversion = sqlite3_libversion_number() : Int32
end

module Ktistec
  module SQLite3
    SQLITE_CONFIG_MEMSTATUS = 9_i32

    if (code = LibSQLite3.config(SQLITE_CONFIG_MEMSTATUS, 1_i32)) != LibSQLite3::Code::OKAY
      Log.warn { "#{code}: couldn't set SQLITE_CONFIG_MEMSTATUS: this is not fatal" }
    end

    TRANSIENT = Pointer(Void*).new(-1)

    private def self.strip_fn(context : LibSQLite3::SQLite3Context, argc : Int32, argv : LibSQLite3::SQLite3Value*)
      txt = LibSQLite3.value_text(argv[0])
      str = String.new(txt)
      unless str.blank?
        str = XML.parse_html(str,
          XML::HTMLParserOptions::RECOVER |
          XML::HTMLParserOptions::NODEFDTD |
          XML::HTMLParserOptions::NOIMPLIED |
          XML::HTMLParserOptions::NOERROR |
          XML::HTMLParserOptions::NOWARNING |
          XML::HTMLParserOptions::NONET
        ).xpath_string("string()")
      end
      LibSQLite3.result_text(context, str, str.bytesize, TRANSIENT)
      nil
    end

    UTF8          = 1
    DETERMINISTIC = 0x000000800
    DIRECTONLY    = 0x000080000

    Ktistec.database.setup_connection do |connection|
      LibSQLite3.create_function(connection, "strip", 1, UTF8 | DETERMINISTIC | DIRECTONLY, nil, ->strip_fn, nil, nil)
    end
  end
end
