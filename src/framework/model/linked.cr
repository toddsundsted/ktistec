require "uri"

require "../model"
require "../open"
require "../signature"

module Ktistec
  module Model
    module Linked
      def origin
        uri = URI.parse(iri)
        "#{uri.scheme}://#{uri.host}"
      end

      def uid
        URI.parse(iri).path.split("/").last
      end

      def local?
        iri.starts_with?(Ktistec.host)
      end

      def cached?
        !local?
      end

      macro included
        @[Persistent]
        property iri : String { "" }
        validates(iri) { unique_absolute_uri?(iri) }

        private def unique_absolute_uri?(iri)
          if iri.blank?
            "must be present"
          elsif !URI.parse(iri).absolute?
            "must be an absolute URI: #{iri}"
          elsif (instance = self.class.find?(iri)) && instance.id != self.id
            "must be unique: #{iri}"
          end
        end

        def self.find(_iri iri : String?)
          find(iri: iri)
        end

        def self.find?(_iri iri : String?)
          find?(iri: iri)
        end

        def self.dereference?(key_pair, iri, ignore_cached = false) : self?
          if iri
            unless (instance = self.find?(iri)) && !ignore_cached
              unless iri.starts_with?(Ktistec.host)
                headers = Ktistec::Signature.sign(key_pair, iri, method: :get)
                headers["Accept"] = "application/activity+json"
                Ktistec::Open.open?(iri, headers) do |response|
                  instance = self.from_json_ld?(response.body)
                end
              end
            end
          end
          instance
        end

        macro finished
          {% verbatim do %}
            {% for type in @type.all_subclasses << @type %}
              {% for m in type.methods.select { |d| d.name.starts_with?("_belongs_to_") } %}
                {% name = m.name[12..-1] %}
                class ::{{type}}
                  def {{name}}?(key_pair, *, dereference = false, ignore_cached = false)
                    {{name}} = self.{{name}}?
                    unless ({{name}} && !ignore_cached) || ({{name}} && {{name}}.changed?)
                      if ({{name}}_iri = self.{{name}}_iri) && dereference
                        unless {{name}}_iri.starts_with?(Ktistec.host)
                          {% for union_type in m.return_type.id.split(" | ").reject(&.==("::Nil")).map(&.id) %}
                            headers = Ktistec::Signature.sign(key_pair, {{name}}_iri, method: :get)
                            headers["Accept"] = "application/activity+json"
                            Ktistec::Open.open?({{name}}_iri, headers) do |response|
                              if ({{name}} = {{union_type}}.from_json_ld?(response.body))
                                return self.{{name}} = {{name}}
                              end
                            end
                          {% end %}
                        end
                      end
                    end
                    {{name}}
                  end
                end
              {% end %}
            {% end %}
          {% end %}
        end
      end
    end
  end
end

# :nodoc:
module Linked
end
