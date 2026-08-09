require "uri"

require "../../../framework/model"
require "../../../utils/network"
require "../../../framework/util"
require "../../../ktistec/constants"
require "../../activity_pub"

module Ktistec
  module Model
    module Linked
      # the only logging in this module is related to
      # dereferencing and mapping JSON-LD.
      Log = ::Log.for("ktistec.json_ld")

      # Raised when an IRI that includes a fragment is dereferenced.
      #
      class FragmentIRI < ::Ktistec::Model::NotFound
      end

      def origin
        uri = URI.parse(iri)
        "#{uri.scheme}://#{uri.host}"
      end

      def self.local?(iri : String) : Bool
        iri_uri = URI.parse(iri)
        host_uri = URI.parse(Ktistec.host)
        iri_uri.scheme == host_uri.scheme &&
          iri_uri.host == host_uri.host &&
          port(iri_uri) == port(host_uri)
      end

      private def self.port(uri : URI) : Int32?
        uri.port || uri.scheme.try { |s| URI.default_port(s) }
      end

      def local?
        Ktistec::Model::Linked.local?(iri)
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

      # Returns `true` if this instance's IRI matches the requested IRI.
      #
      # Override in subclasses to implement custom matching heuristics.
      #
      def iri_matches?(requested_iri : String) : Bool
        iri.compare(requested_iri, case_insensitive: true) == 0
      end

      # Returns `true` if the response carries an ActivityPub /
      # JSON-LD / JSON content type.
      #
      def self.json_response?(response : HTTP::Client::Response) : Bool
        content_type = response.headers["Content-Type"]?.presence
        return true unless content_type
        media_type = content_type.split(';', 2).first.strip.downcase
        media_type.in?("application/activity+json", "application/ld+json", "application/json")
      end

      macro included
        # permits models to have a missing/blank IRI. this is useful
        # for ActivityPub objects that are, for example, sometimes
        # embedded and aren't dereferenceable.

        # IRIs that include URL fragments (i.e., '#fragment') are not
        # dereferenceable. per the ActivityPub spec, these IRIs are
        # just opaque strings.

        @@required_iri : Bool = true

        @[Persistent]
        property iri : String { "" }
        validates(iri) { unique_absolute_uri?(iri) if @@required_iri || iri.presence }

        private def unique_absolute_uri?(iri)
          if iri.blank?
            "must be present"
          elsif !Ktistec::Util.absolute_uri?(iri)
            "must be an absolute URI"
          elsif !Ktistec::Util.safe_iri?(iri)
            "has an unsafe URL scheme"
          elsif (instance = self.class.find?(iri)) && instance.id != self.id
            "must be unique"
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

        def self.dereference?(key_pair, iri, *, ignore_cached = false, include_deleted = false, deadline : ::Time::Instant? = nil, **options) : self?
          dereference(key_pair, iri, **options, ignore_cached: ignore_cached, include_deleted: include_deleted, deadline: deadline)
        rescue ex : ::Ktistec::JSON_LD::MismatchedIRI
          Log.warn { "#{self}.dereference? - #{iri} - #{ex.message}" }
          nil
        rescue ex : ::Ktistec::Model::Linked::FragmentIRI
          Log.debug { "#{self}.dereference? - #{iri} - #{ex.message}" }
          nil
        rescue ::Ktistec::Model::NotFound
          # absence is not a failure
          nil
        rescue ex : ::Ktistec::Network::Error | ::Ktistec::JSON_LD::Error | JSON::ParseException | TypeCastError | NotImplementedError
          Log.info { "#{self}.dereference? - #{iri} - #{ex.message}" }
          nil
        end

        def self.dereference(key_pair, iri, *, ignore_cached = false, include_deleted = false, deadline : ::Time::Instant?, **options) : self
          if ignore_cached || (instance = self.find?(iri, include_deleted: include_deleted)).nil?
            if ::Ktistec::Model::Linked.local?(iri)
              instance = self.find(iri, include_deleted: include_deleted)
            elsif iri.includes?("#")
              raise ::Ktistec::Model::Linked::FragmentIRI.new("URL with fragment is not dereferenceable")
            else
              headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
              Ktistec::Network.get(key_pair, iri, headers, deadline: deadline) do |response|
                if Ktistec::Model::Linked.json_response?(response)
                  instance = self.from_json_ld(response.body, **options)
                  if instance && !instance.iri_matches?(iri)
                    raise ::Ktistec::JSON_LD::MismatchedIRI.new("IRI mismatch: requested #{iri}, got #{instance.iri}")
                  end
                else
                  # a 200 carrying a non-JSON body means no document
                  # was served to parse -- an auth wall or a captive
                  # portal, as often transient as not.
                  raise ::Ktistec::Network::TransientError.new("non-JSON response (#{response.headers["Content-Type"]?})")
                end
              end
            end
          end
          instance || raise ::Ktistec::Model::NotFound.new("#{self} #{iri}: not found")
        end

        # without arguments, or with `dereference: false`, the
        # accessor behaves identically to the similarly named
        # generated accessor in `Model`.

        macro finished
          {% verbatim do %}
            {% for type in @type.all_subclasses << @type %}
              {% for method in type.methods.select(&.name.starts_with?("_association_")) %}
                {% if method.body.first == :belongs_to %}
                  {% name = method.name[13..-1].id %}
                  {% foreign_key = method.body[2].id %}
                  {% clazz = method.body[3].id %}
                  class ::{{type}}
                    def {{name}}?(key_pair, *, dereference = false, ignore_cached = false, ignore_changed = false, include_deleted = false, include_undone = false, deadline : ::Time::Instant? = nil, **options)
                      self.{{name}}(key_pair, **options, dereference: dereference, ignore_cached: ignore_cached, ignore_changed: ignore_changed, include_deleted: include_deleted, include_undone: include_undone, deadline: deadline)
                    rescue ex : ::Ktistec::JSON_LD::MismatchedIRI
                      Log.warn { "#{self.class}##{{{name.stringify}}}? - #{self.{{foreign_key}}} - #{ex.message}" }
                      nil
                    rescue ex : ::Ktistec::Model::Linked::FragmentIRI
                      Log.debug { "#{self.class}##{{{name.stringify}}}? - #{self.{{foreign_key}}} - #{ex.message}" }
                      nil
                    rescue ::Ktistec::Model::NotFound
                      # absence is not a failure
                      nil
                    rescue ex : ::Ktistec::Network::Error | ::Ktistec::JSON_LD::Error | JSON::ParseException | TypeCastError | NotImplementedError
                      Log.info { "#{self.class}##{{{name.stringify}}}? - #{self.{{foreign_key}}} -- #{ex.message}" }
                      nil
                    end

                    def {{name}}(key_pair, *, dereference = false, ignore_cached = false, ignore_changed = false, include_deleted = false, include_undone = false, deadline : ::Time::Instant?, **options)
                      if dereference && ({{foreign_key}} = self.{{foreign_key}})
                        if ignore_changed || ({{name}}_ = self.{{name}}?(include_deleted: include_deleted, include_undone: include_undone)).nil? || (ignore_cached && !{{name}}_.changed?)
                          if ::Ktistec::Model::Linked.local?({{foreign_key}})
                            {{name}}_ = self.{{name}}(include_deleted: include_deleted, include_undone: include_undone)
                          elsif {{foreign_key}}.includes?("#")
                            {{name}}_ = self.{{name}}?(include_deleted: include_deleted, include_undone: include_undone) ||
                              raise ::Ktistec::Model::Linked::FragmentIRI.new("URL with fragment is not dereferenceable")
                          else
                            headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
                            Ktistec::Network.get(key_pair, {{foreign_key}}, headers, deadline: deadline) do |response|
                              if Ktistec::Model::Linked.json_response?(response)
                                {{name}}_ = ActivityPub.from_json_ld(response.body, **options).as({{clazz}})
                                if {{name}}_ && !{{name}}_.iri_matches?({{foreign_key}})
                                  raise ::Ktistec::JSON_LD::MismatchedIRI.new("IRI mismatch: requested #{{{foreign_key}}}, got #{{{name}}_.iri}")
                                else
                                  self.{{name}} = {{name}}_
                                end
                              else
                                # a 200 carrying a non-JSON body means
                                # no document was served to parse -- an
                                # auth wall or a captive portal, as
                                # often transient as not.
                                raise ::Ktistec::Network::TransientError.new("non-JSON response (#{response.headers["Content-Type"]?})")
                              end
                            end
                          end
                        else
                          {{name}}_ = self.{{name}}(include_deleted: include_deleted, include_undone: include_undone)
                        end
                      else
                        {{name}}_ = self.{{name}}(include_deleted: include_deleted, include_undone: include_undone)
                      end
                      {{name}}_ || raise ::Ktistec::Model::NotFound.new("#{self.class} {{name}} #{self.{{foreign_key}}}: not found")
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
