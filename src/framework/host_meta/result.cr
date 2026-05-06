require "json"
require "xml"

module Ktistec
  module HostMeta
    # `Result` error.
    class ResultError < Error
    end

    # A `Ktistec::HostMeta` query result.
    class Result
      class Link
        include JSON::Serializable

        property rel : String
        property type : String?
        property template : String?
        property href : String?

        def initialize(@rel, @type, @template, @href)
        end

        def self.from_xml(xml)
          new(xml["rel"], xml["type"]?, xml["template"]?, xml["href"]?)
        end
      end

      include JSON::Serializable

      property properties : Hash(String, String?)?
      property links : Array(Link)?

      def initialize(@properties, @links)
      end

      def self.from_xml(xml)
        xml = XML.parse(xml).first_element_child
        raise ResultError.new("empty result") unless xml
        ns = xml.namespaces
        xrd =
          begin
            key = ns.key_for?("http://docs.oasis-open.org/ns/xri/xrd-1.0").try(&.split(":")).try(&.last)
            key ? "#{key}:" : ""
          end
        if (nn = xml.xpath_nodes("./#{xrd}Property", ns)).size > 0
          properties =
            nn.reduce(Hash(String, String?).new) do |acc, n|
              acc[n["type"]] = n["nil"]? ? nil : n.content
              acc
            end
        end
        if (nn = xml.xpath_nodes("./#{xrd}Link", ns)).size > 0
          links =
            nn.reduce(Array(Link).new) do |acc, n|
              acc << Link.from_xml(n)
              acc
            end
        end
        new(properties, links)
      end

      def property(key)
        unless (p = @properties)
          raise ResultError.new("No properties in result")
        end
        p[key]
      end

      def property?(key)
        if (p = @properties)
          p.has_key?(key)
        end
      end

      def links(key)
        unless (ln = @links)
          raise ResultError.new("No links in result")
        end
        ln.select { |l| l.rel == key }
      end

      def links?(key)
        if (ln = @links)
          ln.any? { |l| l.rel == key }
        end
      end
    end
  end
end
