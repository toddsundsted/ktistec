require "http"

module Ktistec
  module Open
    extend self

    def open(url, headers = HTTP::Headers.new, attempts = 10, &)
      was = url
      attempts.times do
        response = HTTP::Client.get(url, headers)
        case response.status_code
        when 200
          return yield response
        when 301, 302, 307, 308
          if (tmp = response.headers["Location"]?) && (url = tmp)
            next
          else
            break
          end
        else
          break
        end
      end
      message =
        if was != url
          "Open failed: #{was} [from #{url}]"
        else
          "Open failed: #{was}"
        end
      raise Error.new(message)
    end

    def open(url, headers = HTTP::Headers.new, attempts = 10)
      open(url, headers, attempts) do |response|
        response
      end
    end

    def open?(url, headers = HTTP::Headers.new, attempts = 10, &)
      yield open(url, headers, attempts)
    rescue Error
    end

    def open?(url, headers = HTTP::Headers.new, attempts = 10)
      open?(url, headers, attempts) do |response|
        response
      end
    end

    class Error < Exception
    end
  end
end
