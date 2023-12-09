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
        # permits models to have a missing/blank IRI. this is useful
        # for ActivityPub objects that are, for example, sometimes
        # embedded and aren't dereferenceable.

        @@required_iri : Bool = true

        @[Persistent]
        property iri : String { "" }
        validates(iri) { unique_absolute_uri?(iri) if @@required_iri || iri.presence }

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

        # find local objects if even `ignore_cached` is `true`,
        # because they *do* exist and returning `nil` implies they do
        # not.

        def self.dereference?(key_pair, iri, *, ignore_cached = false, **options) : self?
          if ignore_cached || (instance = self.find?(iri)).nil?
            if iri.starts_with?(Ktistec.host)
              instance = self.find?(iri)
            else
              headers = Ktistec::Signature.sign(key_pair, iri, method: :get)
              headers["Accept"] = Ktistec::Constants::ACCEPT_HEADER
              Ktistec::Open.open?(iri, headers) do |response|
                instance = self.from_json_ld(response.body, **options)
              rescue ex : NotImplementedError | TypeCastError
                # log errors when mapping JSON to a model since `open?`
                # otherwise silently swallows those errors!
                Log.debug { ex.message }
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
                  {% name = method.name[13..-1].id %}
                  {% foreign_key = method.body[2].id %}
                  {% clazz = method.body[3].id %}
                  class ::{{type}}
                    def {{name}}?(key_pair, *, dereference = false, ignore_cached = false, ignore_changed = false, **options)
                      if dereference && ({{foreign_key}} = self.{{foreign_key}})
                        if ignore_changed || ({{name}}_ = self.{{name}}?).nil? || (ignore_cached && !{{name}}_.changed?)
                          if {{foreign_key}}.starts_with?(Ktistec.host)
                            {{name}}_ = self.{{name}}?
                          else
                            headers = Ktistec::Signature.sign(key_pair, {{foreign_key}}, method: :get)
                            headers["Accept"] = Ktistec::Constants::ACCEPT_HEADER
                            Ktistec::Open.open?({{foreign_key}}, headers) do |response|
                              self.{{name}} = {{name}}_ = ActivityPub.from_json_ld(response.body, **options).as({{clazz}})
                            rescue ex : NotImplementedError | TypeCastError
                              # log errors when mapping JSON to a model since `open?`
                              # otherwise silently swallows those errors!
                              Log.debug { ex.message }
                            end
                          end
                        else
                          {{name}}_ = self.{{name}}?
                        end
                      else
                        {{name}}_ = self.{{name}}?
                      end
                      {{name}}_
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
