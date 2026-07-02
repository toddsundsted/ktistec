require "digest/sha256"
require "json"
require "log"
require "uri"

require "../utils/network"

private def wrap(value)
  JSON::Any.new(value)
end

private def empty
  JSON::Any.new(Hash(String, JSON::Any).new)
end

module Ktistec
  module JSON_LD # ameba:disable Naming/TypeNames
    Log = ::Log.for(self)

    class Error < Exception
    end

    # JSON-LD keywords that expansion acts on. Every other keyword
    # (`@graph`, `@included`, `@reverse`, `@list`, `@nest`, …) is
    # dropped and logged, rather than passed through unexpanded where
    # no consumer reads it.
    #
    KEYWORDS = ["@context", "@id", "@type", "@value", "@language"]

    # Expands the JSON-LD document.
    #
    def self.expand(body : JSON::Any | String | IO, loader = Loader.new)
      body = JSON.parse(body) if body.is_a?(String | IO)
      Log.debug { body }
      loader.document_host = document_host(body)
      expand(
        body,
        context(body["@context"]?, loader),
        loader,
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
        original_term = term
        if term.starts_with?("@") || ((defn = term_definition(term, context)) && defn.starts_with?("@") && (term = defn))
          if term.in?(KEYWORDS)
            # `@id`/`@type` are IRI-valued; `@value`/`@language`/`@context`
            # are literals and left raw. only a string `@type` is expanded --
            # a multi-typed array is unsupported (ktistec is single-type).
            if value.as_s? && term.in?("@id", "@type")
              result[term] = expand_iri(value.as_s, context)
            else
              result[term] = value
            end
          else
            Log.warn { "expand: dropping unsupported JSON-LD keyword: #{term}" }
          end
        else
          if term.includes?(":")
            prefix, suffix = term.split(":")
            if context[prefix]? && !suffix.starts_with?("//")
              term = "#{context[prefix]}#{suffix}"
            end
          elsif (defn = term_definition(term, context))
            term = defn
          else
            next
          end
          id_valued = id_valued_term?(original_term, context) || id_valued_term?(term, context)
          value = expand_value(term, value, context, loader, id_valued)
          if result[term]?.try(&.as_h?) && value.as_h?
            result[term] = wrap(result[term].as_h.merge(value.as_h))
          else
            result[term] = value
          end
        end
      end

      # normalize every property value to a set. keywords stay scalar.
      # an array value is not double-wrapped.
      normalized = Hash(String, JSON::Any).new
      result.each do |term, value|
        normalized[term] = (term.starts_with?("@") || value.as_a?) ? value : wrap([value])
      end

      wrap(normalized)
    end

    # Returns the host of the document's own identifier.
    #
    private def self.document_host(body)
      if (id = (body["@id"]? || body["id"]?).try(&.as_s?))
        URI.parse(id).host
      end
    rescue URI::Error
      nil
    end

    private def self.context(context, loader, url = "https://www.w3.org/ns/activitystreams")
      if context.nil?
        context = loader.load(url)
      elsif (url = context.as_s?)
        context = loader.load(url)
        if context.as_h?.try(&.empty?)
          context = loader.load("https://www.w3.org/ns/activitystreams")
        end
      end
      if (contexts = context.as_a?)
        context = contexts.reduce(empty) do |a, c|
          if (u = c.as_s?)
            c = self.context(c, loader)
          end
          wrap(a.as_h.merge(c.as_h))
        end
        if contexts.all?(&.as_s?) && context.as_h?.try(&.empty?)
          context = loader.load("https://www.w3.org/ns/activitystreams")
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
          type = ((_type = result.key_for?("@type")) && (map[_type]?.try(&.as_s))) || (map["@type"]?.try(&.as_s))
          if id
            if type
              result[term] = wrap({
                "@id"   => expand_iri(id, context),
                "@type" => wrap(type),
              })
            else
              result[term] = expand_iri(id, context)
            end
          end
        end
      end

      wrap(result)
    end

    private def self.term_definition(term, context)
      if (defn = context[term]?)
        if (iri = defn.as_s?)
          iri
        elsif (map = defn.as_h?)
          map["@id"]?.try(&.as_s)
        end
      end
    end

    private def self.id_valued_term?(term, context)
      if (defn = context[term]?)
        if (iri = defn.as_s?)
          iri == "@id"
        elsif (map = defn.as_h?)
          map["@type"]?.try(&.as_s) == "@id"
        end
      else
        if (context_map = context.as_h?)
          if (matching_term = context_map.keys.find { |key| term_definition(key, context) == term })
            id_valued_term?(matching_term, context)
          end
        end
      end
    end

    private def self.expand_iri(string, context)
      if string.includes?(":")
        prefix, suffix = string.split(":")
        if context[prefix]? && !suffix.starts_with?("//")
          wrap("#{context[prefix]}#{suffix}")
        else
          if (mapped = term_definition(string, context))
            wrap(mapped)
          else
            wrap(string)
          end
        end
      else
        if (mapped = term_definition(string, context))
          wrap(mapped)
        else
          wrap(string)
        end
      end
    end

    private def self.expand_value(term, value, context, loader, id_valued = false)
      # recognize natural-language properties: coin an "und" map for
      # a plain string, pass everything else through unchanged.
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
          elsif id_valued && v.as_s?
            expand_iri(v.as_s, context)
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
      elsif id_valued && value.as_s?
        expand_iri(value.as_s, context)
      else
        value
      end
    end

    # Digs out the first member of a set.
    #
    # Expansion normalizes every property value to a set; a consumer
    # that wants one value takes the first member of a non-empty set at
    # each level of the selector (an empty set yields `nil`).
    #
    def self.dig_first?(json : JSON::Any, *selector) : JSON::Any?
      current = json
      selector.each do |key|
        if (array = current.as_a?)
          return if array.empty?
          current = array.first
        end
        if (value = current.dig?(key))
          current = value
        else
          return
        end
      end
      if (array = current.as_a?)
        return if array.empty?
        current = array.first
      end
      current
    end

    # Digs out the first member of a set, cast to the given type.
    #
    # See `dig_first?` for the set-collapse behavior.
    #
    def self.dig?(json : JSON::Any, *selector, as : T.class = String) forall T
      if (value = dig_first?(json, *selector))
        {% if T == Int32 %}
          value.as_i?
        {% else %}
          value.raw.as?(T)
        {% end %}
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
      if (value = dig_first?(json, *selector))
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
          dig_first?(json, "https://www.w3.org/ns/activitystreams#href")
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
      # whether to fetch uncached, same-origin contexts
      class_property? fetch_contexts : Bool = true

      class_property memo_ttl : Time::Span = 1.hour

      MAX_MEMO_ENTRIES = 100

      @@memo = {} of String => {String?, Time}

      private ACCEPT_HEADER = HTTP::Headers{"Accept" => "application/ld+json, application/json"}

      property document_host : String?

      def load(url)
        uri = URI.parse(url)
        if uri.path.ends_with?("litepub-0.1.jsonld")
          uri.host = "litepub.social"
          uri.path = ""
        end
        CONTEXTS.dig("#{uri.host}#{uri.path}/context.jsonld", "@context")
      rescue KeyError
        resolve_uncached(url, uri)
      end

      # Resolves an uncached context by fetching it.
      #
      # On a digest match against a bundled context, the *bundled
      # copy* is served; the fetched bytes are never parsed.
      #
      private def resolve_uncached(url, uri)
        key = digest = nil
        if uri && Loader.fetch_contexts? && (host = document_host) && uri.host.try(&.downcase) == host.downcase
          if (entry = @@memo[url]?) && entry[1] > Time.utc
            key = entry[0]
          else
            if (response = Ktistec::Network.get?(nil, url, ACCEPT_HEADER, max_bytes: Ktistec::Network::MAX_DISCOVERY_RESPONSE_BYTES))
              digest = Digest::SHA256.hexdigest(response.body)
              key = DIGESTS[digest]?
            end
            memoize(url, key)
          end
        end
        if key
          CONTEXTS.dig(key, "@context")
        else
          Log.notice { %(uncached external context not loaded: #{url}#{digest ? " [sha256=#{digest}]" : ""}) }
          empty
        end
      end

      private def memoize(url, key)
        if @@memo.size >= MAX_MEMO_ENTRIES
          @@memo.reject! { |_, entry| entry[1] <= Time.utc }
          @@memo.shift if @@memo.size >= MAX_MEMO_ENTRIES
        end
        @@memo[url] = {key, Time.utc + Loader.memo_ttl}
      end
    end

    {% begin %}
      # :nodoc:
      CONTEXTS_RAW = {
        {% contexts = `find "#{__DIR__}/../../etc/contexts" -name '*.jsonld'`.chomp.split("\n").sort %}
        {% for context in (contexts) %}
          {% name = context.split("/etc/contexts/").last %}
          {{name}} => {{read_file(context)}},
        {% end %}
      }
    {% end %}

    # :nodoc:
    CONTEXTS = CONTEXTS_RAW.transform_values { |raw| JSON.parse(raw) }

    # :nodoc:
    DIGESTS = CONTEXTS_RAW.map { |name, raw| {Digest::SHA256.hexdigest(raw), name} }.to_h
  end
end
