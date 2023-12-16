require "http"

module Ktistec
  module Open
    extend self

    def open(url, headers = HTTP::Headers.new, attempts = 10)
      was = url
      message = nil
      attempts.times do
        begin
          response = HTTP::Client.get(url, headers)
          case response.status_code
          when 200
            return response
          when 301, 302, 303, 307, 308
            if (tmp = response.headers["Location"]?) && (url = tmp)
              next
            else
              break
            end
          when 401, 403
            message = "Access denied: #{was}"
            break
          when 500
            message = "Server error: #{was}"
            break
          else
            break
          end
        rescue Socket::Addrinfo::Error
          message = "Hostname lookup failure: #{was}"
        rescue Socket::ConnectError
          message = "Connection failure: #{was}"
        end
      end
      message ||=
        if was != url
          "Failed: #{was} [from #{url}]"
        else
          "Failed: #{was}"
        end
      raise Error.new(message)
    end

    def open(url, headers = HTTP::Headers.new, attempts = 10, &)
      yield open(url, headers, attempts)
    end

    def open?(url, headers = HTTP::Headers.new, attempts = 10)
      open(url, headers, attempts)
    rescue ex : Error
      Log.warn { "#{self}.open? - #{ex.message}" }
    end

    def open?(url, headers = HTTP::Headers.new, attempts = 10, &)
      yield open(url, headers, attempts)
    rescue ex : Error
      Log.warn { "#{self}.open? - #{ex.message}" }
    end

    class Error < Exception
    end
  end
end
