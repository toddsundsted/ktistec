require "./key_pair"

module Ktistec
  # HTTP Signature (https://tools.ietf.org/html/draft-cavage-http-signatures-10)
  # support.
  #
  module Signature
    extend self

    Log = ::Log.for(self)

    class Error < Exception
    end

    def sign(key_pair, url, body = nil, content_type = nil, content_length = nil, accept = nil, method = :post, time = Time.utc, algorithm = "rsa-sha256")
      key = key_pair.private_key.not_nil!
      url = URI.parse(url).normalize
      date = Time::Format::HTTP_DATE.format(time)
      headers_string = "(request-target)"
      signature_string = "(request-target): #{method} #{url.path}"
      signature_params = %Q<keyId="#{key_pair.iri}">
      case algorithm
      when "hs2019"
        headers_string += " (created) (expires) host"
        signature_string += "\n(created): #{time.to_unix}\n(expires): #{time.to_unix + 300}\nhost: #{url.authority}"
        signature_params += %Q<,algorithm="hs2019",created=#{time.to_unix},expires=#{time.to_unix + 300}>
      when "rsa-sha256"
        headers_string += " date host"
        signature_string += "\ndate: #{date}\nhost: #{url.authority}"
        signature_params += %Q<,algorithm="rsa-sha256">
      end
      headers = HTTP::Headers{"Date" => date}
      if body
        digest = "SHA-256=" + Base64.strict_encode(OpenSSL::Digest.new("SHA256").update(body).final)
        headers_string += " digest"
        signature_string += "\ndigest: #{digest}"
        headers["Digest"] = digest
      end
      if accept
        headers_string += " accept"
        signature_string += "\naccept: #{accept}"
        headers["Accept"] = accept
      end
      if content_type
        headers_string += " content-type"
        signature_string += "\ncontent-type: #{content_type}"
        headers["Content-Type"] = content_type
      end
      if content_length
        headers_string += " content-length"
        signature_string += "\ncontent-length: #{content_length}"
        headers["Content-Length"] = content_length.to_s
      end
      signature = Base64.strict_encode(key.sign(OpenSSL::Digest.new("SHA256"), signature_string))
      headers["Signature"] = signature_params + %Q<,signature="#{signature}",headers="#{headers_string}">
      headers
    end

    def verify(key_pair, url, headers, body = nil, method = :post)
      unless (signature = headers["Signature"]?)
        raise Error.new("missing signature")
      end
      parameters = signature.split(",", remove_empty: true).reduce({} of String => String) do |a, h|
        k, v = h.split("=", 2)
        a[k] = v.delete('"')
        a
      end
      unless (parameters.keys.sort! & ["signature", "headers"]).size == 2
        raise Error.new("malformed signature")
      end
      url = URI.parse(url).normalize
      split_headers_string = parameters["headers"].split
      # it's bad to infer the algorithm from an untrusted input, but
      # we need to know how to process the headers (for verification,
      # the algorithm is always assumed to be rsa-sha256).
      algorithm = parameters["algorithm"]? || begin
        "date".in?(split_headers_string) ? "rsa-sha256" : "hs2019"
      end
      unless "(request-target)".in?(split_headers_string)
        raise Error.new("(request-target) header must be signed")
      end
      if "(created)".in?(split_headers_string) && algorithm.starts_with?(/rsa|hmac|ecdsa/)
        raise Error.new("(created) header must not be used with #{algorithm}")
      end
      if "(expires)".in?(split_headers_string) && algorithm.starts_with?(/rsa|hmac|ecdsa/)
        raise Error.new("(expires) header must not be used with #{algorithm}")
      end
      unless "(created)".in?(split_headers_string) || "date".in?(split_headers_string)
        raise Error.new("(created) header or date header must be signed")
      end
      unless "host".in?(split_headers_string)
        raise Error.new("host header must be signed")
      end
      unless method != :post || "digest".in?(split_headers_string)
        raise Error.new("body digest must be signed")
      end
      signature_string =
        split_headers_string.compact_map do |header|
          case header
          when "(request-target)"
            "#{header}: #{method} #{url.path}"
          when "(created)"
            "#{header}: #{parameters["created"]}"
          when "(expires)"
            "#{header}: #{parameters["expires"]}"
          when "date"
            "#{header}: #{headers["Date"]}"
          when "host"
            "#{header}: #{url.authority}"
          when "accept"
            "#{header}: #{headers["Accept"]}"
          when "content-type"
            "#{header}: #{headers["Content-Type"]}"
          when "content-length"
            "#{header}: #{headers["Content-Length"]}"
          when "digest"
            "#{header}: #{headers["Digest"]}"
          end
        end.join("\n")
      key = key_pair.public_key
      unless key.try(&.verify(OpenSSL::Digest.new("SHA256"), Base64.decode(parameters["signature"]), signature_string))
        raise Error.new("invalid signature: signed by keyId=#{parameters["keyId"]}")
      end
      # five minutes of leeway for clock skew
      if "(created)".in?(split_headers_string)
        created = Time.unix(Int64.new(parameters["created"]))
        unless created < 5.minutes.from_now
          raise Error.new("received before creation date")
        end
      end
      if "(expires)".in?(split_headers_string)
        expires = Time.unix(Int64.new(parameters["expires"]))
        unless expires > 5.minutes.ago
          raise Error.new("received after expiration date")
        end
      end
      if "date".in?(split_headers_string)
        date = Time::Format::HTTP_DATE.parse(headers["Date"])
        unless date > 5.minutes.ago && date < 5.minutes.from_now
          raise Error.new("date out of range")
        end
      end
      if "digest".in?(split_headers_string)
        digest = "SHA-256=" + Base64.strict_encode(OpenSSL::Digest.new("SHA256").update(body.not_nil!).final)
        unless headers["Digest"]? == digest
          raise Error.new("body doesn't match")
        end
      end
      true
    end

    def verify?(key_pair, url, headers, *args, **opts)
      verify(key_pair, url, headers, *args, **opts)
    rescue ex : Error | OpenSSL::Error
      Log.debug { "verification failed: #{ex.message}" }
      false
    end
  end
end
