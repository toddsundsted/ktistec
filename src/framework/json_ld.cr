require "json"
require "uri"

module Balloon
  module JSON_LD
    # Expands the JSON-LD document.
    #
    def self.expand(body, loader = Loader.new)
      expand(
        body,
        context(body["@context"]? || empty, loader),
        loader
      )
    end

    private def self.empty
      wrap(Hash(String, JSON::Any).new)
    end

    private def self.wrap(value)
      JSON::Any.new(value)
    end

    private def self.expand(body, context, loader)
      result = Hash(String, JSON::Any).new

      body.as_h.each do |term, value|
        value =
          if value.as_a?
            val = value.as_a.map do |v|
              v.as_h? ? expand(v, context, loader) : v
            end
            wrap(val)
          elsif value.as_h?
            expand(value, context, loader)
          else
            value
          end

        if term.includes?(":")
          prefix, suffix = term.split(":")
          if context[prefix]? && !suffix.starts_with?("//")
            result["#{context[prefix]}#{suffix}"] = value
          else
            result[term] = value
          end
        elsif term.starts_with?("@")
          if value.as_s?
            result[term] = _expand(value.as_s, context)
          else
            result[term] = value
          end
        elsif defn = context[term]?.try(&.as_s)
          if defn.starts_with?("@") && value.as_s?
            result[defn] = _expand(value.as_s, context)
          else
            result[defn] = value
          end
        end
      end

      wrap(result)
    end

    private def self.context(context, loader)
      result = Hash(String, JSON::Any).new

      if url = context.as_s?
        context = loader.load(url)["@context"]
      elsif array = context.as_a?
        context = array.reduce(empty) do |a, c|
          if u = c.as_s?
            c = loader.load(u)["@context"]
          end
          wrap(a.as_h.merge(c.as_h))
        end
      end

      context.as_h.each do |term, defn|
        if term.includes?(":")
          prefix, suffix = term.split(":")
          term = "#{context[prefix]}#{suffix}"
        end
        if iri = defn.as_s?
          result[term] = _expand(iri, context)
        elsif map = defn.as_h?
          result[term] = _expand(map["@id"].as_s, context)
        end
      end

      wrap(result)
    end

    private def self._expand(string, context)
      if string.includes?(":")
        prefix, suffix = string.split(":")
        if context[prefix]? && !suffix.starts_with?("//")
          wrap("#{context[prefix]}#{suffix}")
        else
          context[string]? || wrap(string)
        end
      else
        context[string]? || wrap(string)
      end
    end

    # Loads context from cache.
    #
    class Loader
      def load(url)
        uri = URI.parse(url)
        CONTEXTS["#{uri.host}#{uri.path}/context.jsonld"]
      end
    end

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
