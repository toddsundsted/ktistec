require "crypto/subtle"
require "openssl/hmac"

module Ktistec
  module JWT
    class Error < Exception
    end

    # Encodes the payload. Generates a token.
    #
    def self.encode(payload, secret_key = Ktistec.secret_key)
      parts = [] of String
      header = {"typ" => "JWT", "alg" => "HS256"}
      parts << encode64(header.to_json)
      parts << encode64(payload.to_json)
      parts << encode64(sign(parts.join("."), secret_key))
      parts.join(".")
    end

    # Decodes the token. Returns the payload.
    #
    def self.decode(token, secret_key = Ktistec.secret_key)
      hashed_header, hashed_payload, hashed_signature = token.split(".")
      verified = verify(
        Base64.decode_string(hashed_signature),
        "#{hashed_header}.#{hashed_payload}",
        secret_key,
      )
      raise Error.new unless verified
      JSON.parse(Base64.decode_string(hashed_payload))
    rescue ex : JSON::ParseException | Base64::Error | IndexError
      raise Error.new(ex.message)
    end

    def self.expired?(payload)
      Time.parse_iso8601(payload["iat"].as_s) < Time.utc - 1.month
    end

    private def self.encode64(str)
      Base64.urlsafe_encode(str, padding: false)
    end

    private def self.sign(str, key)
      OpenSSL::HMAC.digest(:sha256, key, str)
    end

    private def self.verify(sig, str, key)
      Crypto::Subtle.constant_time_compare(sign(str, key), sig)
    end
  end
end
