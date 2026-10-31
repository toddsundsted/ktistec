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

    def sign(key_pair, url, body = nil, content_type = nil, content_length = nil, accept = nil, method = :post, time = Time.utc, algorithm = "rsa-sha256")
      Cavage.sign(key_pair, url, body, content_type, content_length, accept, method, time, algorithm)
    end

    def parse(headers)
      Cavage.parse(headers)
    end
  end
end

require "./signature/cavage"
