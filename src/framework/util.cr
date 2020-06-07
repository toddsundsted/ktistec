module Balloon
  module Util
    extend self

    def open(url, headers = HTTP::Headers{"Accept" => "application/activity+json"}, attempts = 10)
      open(url, headers, attempts) do |response|
        return response
      end
    end

    def open(url, headers = HTTP::Headers{"Accept" => "application/activity+json"}, attempts = 10)
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
      raise OpenError.new(message)
    end

    class OpenError < Exception
    end

    class PaginatedArray(T) < Array(T)
      def more=(more : Bool)
        @more = more
      end

      def more?
        @more
      end
    end
  end
end
