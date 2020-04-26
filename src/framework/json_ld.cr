require "json"

module Balloon
  module JSON_LD
    {% begin %}
      # :nodoc:
      CONTEXTS = {
        {% contexts = `find "#{__DIR__}/../../etc/contexts" -name '*.jsonld'`.chomp.split("\n").sort %}
        {% for context in (contexts) %}
          {% name = context.split("/etc/contexts/").last %}
          {{name}} => JSON.parse(
            {{read_file(context)}}
          ),
        {% end %}
      }
    {% end %}
  end
end
