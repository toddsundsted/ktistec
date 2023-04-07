require "uri"

require "../../../framework/model"
require "../../../framework/open"
require "../../../framework/signature"
require "../../../framework/constants"
require "../../activity_pub"

module Ktistec
  module Model(*T)
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

      def to_s(io : IO)
        io << "#<"
        self.class.to_s(io)
        io << " iri="
        self.iri.to_s(io)
        io << ">"
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

        def self.find(_iri iri : String?, include_deleted : Bool = false, include_undone : Bool = false)
          find(iri: iri, include_deleted: include_deleted, include_undone: include_undone)
        end

        def self.find?(_iri iri : String?, include_deleted : Bool = false, include_undone : Bool = false)
          find?(iri: iri, include_deleted: include_deleted, include_undone: include_undone)
        end

        def self.dereference?(key_pair, iri, *, ignore_cached = false, **options) : self?
          unless !ignore_cached && (instance = self.find?(iri))
            unless iri.starts_with?(Ktistec.host)
              headers = Ktistec::Signature.sign(key_pair, iri, method: :get)
              headers["Accept"] = Ktistec::Constants::ACCEPT_HEADER
              Ktistec::Open.open?(iri, headers) do |response|
                instance = self.from_json_ld?(response.body, **options)
              end
            end
          end
          instance
        end

        # without arguments, or with `dereference: false`, the
        # accessor behaves identically to the similarly named
        # generated accessor in `Model`.

        macro finished
          {% verbatim do %}
            {% for type in @type.all_subclasses << @type %}
              {% for method in type.methods.select { |d| d.name.starts_with?("_association_") } %}
                {% if method.body.first == :belongs_to %}
                  {% name = method.name[13..-1] %}
                  class ::{{type}}
                    def {{name}}?(key_pair, *, dereference = false, ignore_cached = false, ignore_changed = false, **options)
                      {{name}} = self.{{name}}?
                      if dereference && ({{name}}_iri = self.{{name}}_iri)
                        if {{name}}.nil? || (ignore_cached && !{{name}}.changed?) || ignore_changed
                          unless {{name}}_iri.starts_with?(Ktistec.host)
                            headers = Ktistec::Signature.sign(key_pair, {{name}}_iri, method: :get)
                            headers["Accept"] = Ktistec::Constants::ACCEPT_HEADER
                            Ktistec::Open.open?({{name}}_iri, headers) do |response|
                              {{name}} = ActivityPub.from_json_ld?(response.body, **options).as({{method.body[3].id}})
                              return self.{{name}} = {{name}}
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
          {% end %}
        end
      end
    end
  end
end

# :nodoc:
module Linked
end
