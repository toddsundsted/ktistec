require "./key_pair"

module Ktistec
  # HTTP Signature (https://tools.ietf.org/html/draft-cavage-http-signatures-10)
  # support.
  #
  module Signature
    extend self

    class Error < Exception
    end

    def sign(key_pair, url, body = nil, content_type = nil, method = :post, time = Time.utc)
      key = key_pair.private_key.not_nil!
      url = URI.parse(url)
      date = Time::Format::HTTP_DATE.format(time)
      headers_string = "(request-target) host date"
      signature_string = "(request-target): #{method} #{url.path}\nhost: #{url.host}\ndate: #{date}"
      headers = HTTP::Headers{"Date" => date}
      if body
        digest = "SHA-256=" + Base64.strict_encode(OpenSSL::Digest.new("SHA256").update(body).final)
        headers_string += " digest"
        signature_string += "\ndigest: #{digest}"
        headers["Digest"] = digest
      end
      if content_type
        headers_string += " content-type"
        signature_string += "\ncontent-type: #{content_type}"
        headers["Content-Type"] = content_type
      end
      signature = Base64.strict_encode(key.sign(OpenSSL::Digest.new("SHA256"), signature_string))
      signature = %Q<keyId="#{key_pair.iri}",signature="#{signature}",headers="#{headers_string}">
      headers["Signature"] = signature
      headers
    end

    def verify(key_pair, url, headers, body = nil, method = :post)
      unless (signature = headers["Signature"]?)
        raise Error.new("missing signature")
      end
      parameters = signature.split(",", remove_empty: true).reduce({} of String => String) do |a, h|
        k, v = h.split("=", 2)
        a[k] = v[1..-2]
        a
      end
      unless (parameters.keys.sort & ["signature", "headers"]).size == 2
        raise Error.new("malformed signature")
      end
      url = URI.parse(url)
      time = headers["Date"]
      split_headers_string = parameters["headers"].split
      unless "(request-target)".in?(split_headers_string)
        raise Error.new("request target must be signed")
      end
      unless "host".in?(split_headers_string)
        raise Error.new("host header must be signed")
      end
      unless "date".in?(split_headers_string)
        raise Error.new("date header must be signed")
      end
      unless "digest".in?(split_headers_string) || method != :post
        raise Error.new("body digest must be signed")
      end
      signature_string =
        split_headers_string.map do |header|
          case header
          when "(request-target)"
            "#{header}: #{method} #{url.path}"
          when "host"
            "#{header}: #{url.host}"
          when "date"
            "#{header}: #{time}"
          when "content-type"
            "#{header}: #{headers["Content-Type"]}"
          when "digest"
            "#{header}: #{headers["Digest"]}"
          end
        end.compact.join("\n")
      key = key_pair.public_key
      unless key.try(&.verify(OpenSSL::Digest.new("SHA256"), Base64.decode(parameters["signature"]), signature_string))
        raise Error.new("invalid signature: signed by keyId=#{parameters["keyId"]}")
      end
      if "date".in?(split_headers_string)
        time = Time::Format::HTTP_DATE.parse(time)
        unless time > 5.minutes.ago && time < 5.minutes.from_now
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
      Log.info { "verification failed: #{ex.message}" }
      false
    end
  end
end
