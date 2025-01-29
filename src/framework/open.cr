require "http"
require "uri"

require "./signature"

module Ktistec
  module Open
    extend self

    Log = ::Log.for(self)

    # Opens and reads from the specified URL.
    #
    # Uses `key_pair` to sign the request. Will automatically follow
    # `attempts` redirects (default 10).
    #
    def open(key_pair, url, headers = HTTP::Headers.new, attempts = 10)
      was = url
      message = "Failed"
      attempts.times do
        start = Time.monotonic
        begin
          uri = URI.parse(url)
          client = HTTP::Client.new(uri)
          client.dns_timeout = 5.seconds
          client.connect_timeout = 5.seconds
          client.write_timeout = 5.seconds
          client.read_timeout = 5.seconds
          signed_headers = Ktistec::Signature.sign(key_pair, url, method: :get).merge!(headers)
          response = client.get(uri.request_target, signed_headers)
          case response.status_code
          when 200
            return response
          when 301, 302, 303, 307, 308
            if (tmp = response.headers["Location"]?) && (url = uri.resolve(tmp).to_s)
              next
            else
              message = "Could not redirect [#{response.status_code}] [#{tmp}]"
              break
            end
          when 401, 403
            message = "Access denied [#{response.status_code}]"
            break
          when 404, 410
            message = "Does not exist [#{response.status_code}]"
            break
          when 500
            message = "Server error [#{response.status_code}]"
            break
          else
            break
          end
        rescue URI::Error
          message = "Invalid URI"
          break
        rescue Socket::Addrinfo::Error
          message = "Hostname lookup failure"
          break
        rescue Socket::ConnectError
          message = "Connection failure"
          break
        rescue OpenSSL::Error
          message = "Secure connection failure"
          break
        rescue IO::TimeoutError # subclass of IO::Error
          message = "Timeout [#{(Time.monotonic - start).to_i}s]"
          break
        rescue IO::Error
          message = "I/O error"
          break
        rescue Compress::Deflate::Error | Compress::Gzip::Error
          message = "Encoding error"
          break
        end
      end
      message =
        if was != url
          "#{message}: #{was} [from #{url}]"
        else
          "#{message}: #{was}"
        end
      raise Error.new(message)
    end

    # :ditto:
    def open(key_pair, url, headers = HTTP::Headers.new, attempts = 10, &)
      yield open(key_pair, url, headers, attempts)
    end

    # :ditto:
    def open?(key_pair, url, headers = HTTP::Headers.new, attempts = 10)
      open(key_pair, url, headers, attempts)
    rescue ex : Error
      Log.debug { "#{self}.open? - #{ex.message}" }
    end

    # :ditto:
    def open?(key_pair, url, headers = HTTP::Headers.new, attempts = 10, &)
      yield open(key_pair, url, headers, attempts)
    rescue ex : Error
      Log.debug { "#{self}.open? - #{ex.message}" }
    end

    class Error < Exception
    end
  end
end
