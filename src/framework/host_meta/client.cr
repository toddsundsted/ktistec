require "http/client"

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
        url = "https://#{host}/.well-known/host-meta"
        attempts.times do
          response = HTTP::Client.get(url)
          case (code = response.status_code)
          when 200
            mt = response.mime_type.try(&.media_type)
            return (
              if mt =~ /xml/
                Result.from_xml(response.body)
              elsif mt =~ /json/
                Result.from_json(response.body)
              elsif response.body.starts_with?('{')
                Result.from_json(response.body)
              else
                Result.from_xml(response.body)
              end
            )
          when 300, 301, 302, 303, 307, 308
            if (tmp = response.headers["Location"]?) && (url = tmp)
              next
            else
              break
            end
          when 404
            raise NotFoundError.new("not found [#{code}]: #{url}")
          else
            raise Error.new("error [#{code}]: #{url}")
          end
        end
        raise RedirectionError.new("redirection failed: #{url}")
      rescue err : JSON::ParseException
        raise ResultError.new(err.message)
      rescue err : IO::Error | OpenSSL::Error | Compress::Deflate::Error | Compress::Gzip::Error
        raise NotFoundError.new(err.message)
      end
    end
  end
end
