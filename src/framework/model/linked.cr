require "../model"

module Balloon
  module Model
    module Linked
      macro included
        macro finished
          {% verbatim do %}
            {% for type in @type.all_subclasses << @type %}
              {% for m in type.methods.select { |d| d.name.starts_with?("_belongs_to_") } %}
                {% name = m.name[12..-1] %}
                class ::{{type}}
                  extend Balloon::Util

                  def {{name}}?(*, dereference = false)
                    unless ({{name}} = self.{{name}}?)
                      if ({{name}}_iri = self.{{name}}_iri) && dereference
                        unless {{name}}_iri.starts_with?(Balloon.host)
                          {{m.return_type}}.open?({{name}}_iri) do |response|
                            if ({{name}} = {{m.return_type}}.from_json_ld?(response.body))
                              self.{{name}} = {{name}}
                            end
                          end
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
