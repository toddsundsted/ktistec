require "./key_pair"

module Ktistec
  # HTTP Signature support.
  #
  # Delegates to the implementation of each supported version.
  #
  module Signature
    extend self

    class Error < Exception
    end

    # The formats outbound requests are signed with, in order.
    #
    FORMATS = {Cavage, RFC9421}

    RETRY_STATUSES = {400, 401}

    def sign(key_pair, url, body = nil, content_type = nil, content_length = nil, accept = nil, method = :post, time = Time.utc, algorithm = "rsa-sha256")
      Cavage.sign(key_pair, url, body, content_type, content_length, accept, method, time, algorithm)
    end

    def parse(headers)
      if headers.has_key?("Signature-Input")
        RFC9421.parse(headers)
      else
        Cavage.parse(headers)
      end
    end
  end
end

require "./signature/cavage"
require "./signature/rfc9421"
