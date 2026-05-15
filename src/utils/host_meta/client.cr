require "../network"

module Ktistec
  module HostMeta
    # General error.
    class Error < Exception
    end

    # Address not found error.
    class NotFoundError < Error
    end

    # Redirection failed.
    class RedirectionError < Error
    end

    # The client.
    module Client
      # Returns the result of querying the specified host.
      #
      #     h = Ktistec::HostMeta.query("epiktistes.com") # => #<Ktistec::HostMeta::Result:0x10e99...>
      #     h.links("lrdd").first.template # => "https://epiktistes.com/.well-known/webfinger?resource={uri}"
      #
      # Raises `Ktistec::HostMeta::NotFoundError` if the host does not exist and
      # `Ktistec::HostMeta::RedirectionError` if redirection failed. Otherwise,
      # returns `Ktistec::HostMeta::Result`.
      #
      def self.query(host, attempts = 10)
        response = Ktistec::Network.get("https://#{host}/.well-known/host-meta", attempts: attempts, max_bytes: Ktistec::Network::MAX_DISCOVERY_RESPONSE_BYTES)
        mt = response.mime_type.try(&.media_type)
        if mt =~ /xml/
          Result.from_xml(response.body)
        elsif mt =~ /json/
          Result.from_json(response.body)
        elsif response.body.starts_with?('{')
          Result.from_json(response.body)
        else
          Result.from_xml(response.body)
        end
      rescue err : JSON::ParseException
        raise ResultError.new(err.message)
      rescue err : Ktistec::Network::Error
        raise NotFoundError.new(err.message)
      end
    end
  end
end
