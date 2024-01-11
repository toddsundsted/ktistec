require "http"

require "./signature"

module Ktistec
  module Open
    extend self

    # Opens and reads from the specified URL.
    #
    # Uses `key_pair` to sign the request. Will automatically follow
    # `attempts` redirects (default 10).
    #
    def open(key_pair, url, headers = HTTP::Headers.new, attempts = 10)
      was = url
      message = "Failed"
      attempts.times do
        begin
          signed_headers = Ktistec::Signature.sign(key_pair, url, method: :get).merge!(headers)
          response = HTTP::Client.get(url, signed_headers)
          case response.status_code
          when 200
            return response
          when 301, 302, 303, 307, 308
            if (tmp = response.headers["Location"]?) && (url = URI.parse(url).resolve(tmp).to_s)
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
        rescue Socket::Addrinfo::Error
          message = "Hostname lookup failure"
        rescue Socket::ConnectError
          message = "Connection failure"
        rescue OpenSSL::Error
          message = "Secure connection failure"
        rescue IO::Error
          message = "I/O error"
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
      Log.warn { "#{self}.open? - #{ex.message}" }
    end

    # :ditto:
    def open?(key_pair, url, headers = HTTP::Headers.new, attempts = 10, &)
      yield open(key_pair, url, headers, attempts)
    rescue ex : Error
      Log.warn { "#{self}.open? - #{ex.message}" }
    end

    class Error < Exception
    end
  end
end
