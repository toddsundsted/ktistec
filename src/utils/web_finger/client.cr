require "../host_meta"
require "../../framework/open"

module Ktistec
  module WebFinger
    # General error.
    class Error < Exception
    end

    # Account not found error.
    class NotFoundError < Error
    end

    # Redirection failed.
    class RedirectionError < Error
    end

    # The client.
    module Client
      ACCOUNT_REGEX = %r<
        ^https://(?<host>[^/]+)(/.*)?$|
        ^([^@]+)@(?<host>[^@]+)$|
        ^(?<host>.+)$
      >mx

      # Returns the result of querying for the specified account.
      #
      # The account should conform to the ['acct' URI Scheme](https://tools.ietf.org/html/rfc7565).
      # Liberal validation of this format eases federation with other popular servers.
      #
      #     w = Ktistec::WebFinger.query("acct:toddsundsted@epiktistes.com") # => #<Ktistec::WebFinger::Result:0x108d...>
      #     w.link("http://webfinger.net/rel/profile-page").href # => "https://epiktistes.com/@toddsundsted"
      #
      # Raises `Ktistec::WebFinger::NotFoundError` if the account does not exist
      # and `Ktistec::WebFinger::RedirectionError` if redirection failed.
      # Otherwise, returns `Ktistec::WebFinger::Result`.
      #
      def self.query(account, attempts = 10)
        unless account =~ ACCOUNT_REGEX
          raise Error.new("invalid account: #{account}")
        end

        host = $~["host"]?

        template =
          begin
            Ktistec::HostMeta.query(host).links("lrdd").first.template.not_nil!
          rescue Ktistec::HostMeta::Error | NilAssertionError | IndexError
            "https://#{host}/.well-known/webfinger?resource={uri}"
          end

        url = template.gsub("{uri}", URI.encode_www_form(account))

        response = Ktistec::Open.open(url, attempts: attempts)
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
      rescue err : Ktistec::Open::Error
        raise NotFoundError.new(err.message)
      end
    end
  end
end
