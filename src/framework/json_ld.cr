require "json"
require "log"
require "uri"

private def empty
  wrap(Hash(String, JSON::Any).new)
end

private def wrap(value)
  JSON::Any.new(value)
end

module Ktistec
  module JSON_LD
    # Expands the JSON-LD document.
    #
    def self.expand(body, loader = Loader.new)
      body = JSON.parse(body) if body.is_a?(String | IO)
      Log.info { body }
      expand(
        body,
        context(body["@context"]?, loader),
        loader
      )
    end

    private def self.expand(body, context, loader)
      result = Hash(String, JSON::Any).new

      body.as_h.each do |term, value|
        if term.starts_with?("@") || ((defn = context[term]?.try(&.as_s)) && defn.starts_with?("@") && (term = defn))
          if value.as_s?
            result[term] = expand_iri(value.as_s, context)
          else
            result[term] = value
          end
        else
          if term.includes?(":")
            prefix, suffix = term.split(":")
            if context[prefix]? && !suffix.starts_with?("//")
              term = "#{context[prefix]}#{suffix}"
            end
          elsif (defn = context[term]?.try(&.as_s))
            term = defn
          else
            next
          end
          value = expand_value(term, value, context, loader)
          if result[term]?.try(&.as_h?) && value.as_h?
            result[term] = wrap(result[term].as_h.merge(value.as_h))
          else
            result[term] = value
          end
        end
      end

      wrap(result)
    end

    private def self.context(context, loader, url = "https://www.w3.org/ns/activitystreams")
      if context.nil?
        context = loader.load(url)
      elsif (url = context.as_s?)
        context = loader.load(url)
      end
      if (contexts = context.as_a?)
        context = contexts.reduce(empty) do |a, c|
          if (u = c.as_s?)
            c = self.context(c, loader)
          end
          wrap(a.as_h.merge(c.as_h))
        end
      end

      result = Hash(String, JSON::Any).new

      context.as_h.each do |term, defn|
        if term.includes?(":")
          prefix, suffix = term.split(":")
          term = "#{context[prefix]}#{suffix}"
        end
        if (iri = defn.as_s?)
          result[term] = expand_iri(iri, context)
        elsif (map = defn.as_h?)
          id = ((_id = result.key_for?("@id")) && (map[_id]?.try(&.as_s))) || (map["@id"]?.try(&.as_s))
          result[term] = expand_iri(id, context) if id
        end
      end

      wrap(result)
    end

    private def self.expand_iri(string, context)
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

    private def self.expand_value(term, value, context, loader)
      if term.in?(["https://www.w3.org/ns/activitystreams#content", "https://www.w3.org/ns/activitystreams#name", "https://www.w3.org/ns/activitystreams#summary", "https://www.w3.org/ns/activitystreams#attachment"])
        value.as_s? ? wrap({"und" => value}) : value
      elsif value.as_a?
        wrap(value.as_a.map { |v| v.as_h? ? expand(v, context, loader) : v })
      elsif value.as_h?
        expand(value, context, loader)
      else
        value
      end
    end

    # Loads context from cache.
    #
    class Loader
      def load(url)
        uri = URI.parse(url)
        if uri.path.ends_with?("litepub-0.1.jsonld")
          uri.host = "litepub.social"
          uri.path = ""
        end
        CONTEXTS.dig("#{uri.host}#{uri.path}/context.jsonld", "@context")
      rescue KeyError
        Log.info { "uncached external context not loaded: #{url}" }
        empty
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
