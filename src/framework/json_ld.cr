require "json"
require "log"
require "uri"

private def wrap(value)
  JSON::Any.new(value)
end

private def empty
  JSON::Any.new(Hash(String, JSON::Any).new)
end

module Ktistec
  module JSON_LD
    Log = ::Log.for(self)

    class Error < Exception
    end

    # Expands the JSON-LD document.
    #
    def self.expand(body : JSON::Any | String | IO, loader = Loader.new)
      body = JSON.parse(body) if body.is_a?(String | IO)
      Log.debug { body }
      expand(
        body,
        context(body["@context"]?, loader),
        loader
      )
    rescue ex
      # methods on JSON::Any raise the base class `Exception` which
      # makes selective catching and handling of errors elsewhere more
      # difficult. this is kludgey but catch those exceptions and
      # raise something class specific, instead.
      raise Error.new(ex.message)
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
      if term.in?(["https://www.w3.org/ns/activitystreams#content", "https://www.w3.org/ns/activitystreams#name", "https://www.w3.org/ns/activitystreams#summary"])
        value.as_s? ? wrap({"und" => value}) : value
      elsif value.as_a?
        array = value.as_a.map do |v|
          if v.as_h?
            new_context = context
            if v["@context"]?
              c = context(v["@context"]?, loader)
              new_context = wrap(new_context.as_h.merge(c.as_h))
            end
            expand(v, new_context, loader)
          else
            v
          end
        end
        wrap(array)
      elsif value.as_h?
        new_context = context
        if value["@context"]?
          c = context(value["@context"]?, loader)
          new_context = wrap(new_context.as_h.merge(c.as_h))
        end
        expand(value, new_context, loader)
      else
        value
      end
    end

    def self.dig?(json : JSON::Any, *selector, as : T.class = String) forall T
      json.dig?(*selector).try(&.raw.as?(T))
    end

    def self.dig_value?(json, *selector, &)
      if (value = json.dig?(*selector))
        if (values = value.as_a?)
          values.map { |v| yield v }.first
        else
          yield value
        end
      end
    end

    def self.dig_values?(json, *selector, &)
      if (value = json.dig?(*selector))
        if (values = value.as_a?)
          values.map { |v| yield v }
        else
          [yield value]
        end.compact
      end
    end

    def self.dig_id?(json, *selector)
      dig_value?(json, *selector) do |value|
        dig_identifier(value).try(&.as_s?)
      end
    end

    def self.dig_ids?(json, *selector)
      dig_values?(json, *selector) do |value|
        dig_identifier(value).try(&.as_s?)
      end
    end

    private def self.dig_identifier(json)
      if (hash = json.as_h?)
        if hash.dig?("@type") == "https://www.w3.org/ns/activitystreams#Link"
          hash.dig?("https://www.w3.org/ns/activitystreams#href")
        else
          hash.dig?("@id")
        end
      else
        json
      end
    end

    # Loads context from cache.
    #
    # Exposed for testing. Should not be used directly.
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
        Log.notice { "uncached external context not loaded: #{url}" }
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
