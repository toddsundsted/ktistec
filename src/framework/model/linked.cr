require "../model"
require "../open"

module Ktistec
  module Model
    module Linked
      macro included
        extend Ktistec::Open

        def initialize(**options)
          super(**options)
        end

        @[Persistent]
        property iri : String { "" }
        validates(iri) { unique_absolute_uri?(iri) }

        private def unique_absolute_uri?(iri)
          if iri.blank?
            "must be present"
          elsif !URI.parse(iri).absolute?
            "must be an absolute URI"
          elsif (instance = self.class.find?(iri)) && instance.id != self.id
            "must be unique"
          end
        end

        def local?
          iri.starts_with?(Ktistec.host)
        end

        def self.find(_iri iri : String?)
          find(iri: iri)
        end

        def self.find?(_iri iri : String?)
          find?(iri: iri)
        end

        def self.dereference?(iri : String?) : self?
          if iri
            unless (instance = self.find?(iri))
              unless iri.starts_with?(Ktistec.host)
                self.open?(iri) do |response|
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
                  def {{name}}?(*, dereference = false)
                    unless ({{name}} = self.{{name}}?)
                      if ({{name}}_iri = self.{{name}}_iri) && dereference
                        unless {{name}}_iri.starts_with?(Ktistec.host)
                          {% for union_type in m.return_type.id.split("|").map(&.strip.id) %}
                            {{union_type}}.open?({{name}}_iri) do |response|
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
