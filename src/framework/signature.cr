require "./framework"

module Balloon
  # HTTP Signature (https://tools.ietf.org/html/draft-cavage-http-signatures-10)
  # support.
  #
  module Signature
    class Error < Exception
    end

    def self.sign(actor, url, time = Time.utc)
      url = URI.parse(url)
      time = Time::Format::HTTP_DATE.format(time)
      signature_string = "(request-target): post #{url.path}\nhost: #{url.host}\ndate: #{time}"
      key = actor.private_key.not_nil!
      signature = Base64.strict_encode(key.sign(OpenSSL::Digest.new("SHA256"), signature_string))
      header = %Q<keyId="#{actor.iri}",signature="#{signature}",headers="(request-target) host date">
      HTTP::Headers{"Signature" => header, "Date" => time}
    end

    def self.verify(actor, url, headers)
      unless (header = headers["Signature"]?)
        raise Error.new("missing signature")
      end
      parameters = header.split(",", remove_empty: true).reduce({} of String => String) do |a, h|
        k, v = h.split("=", 2)
        a[k] = v[1..-2]
        a
      end
      unless (parameters.keys.sort & ["keyId", "signature", "headers"]).size == 3
        raise Error.new("malformed signature")
      end
      unless parameters["keyId"] == actor.iri
        raise Error.new("invalid keyId")
      end
      url = URI.parse(url)
      time = headers["Date"]
      signature_string =
        parameters["headers"].split.map do |header|
          case header
          when "(request-target)"
            "#{header}: post #{url.path}"
          when "host"
            "#{header}: #{url.host}"
          when "date"
            "#{header}: #{time}"
          end
        end.compact.join("\n")
      key = actor.public_key
      unless key.try(&.verify(OpenSSL::Digest.new("SHA256"), Base64.decode(parameters["signature"]), signature_string))
        raise Error.new("invalid signature")
      end
      unless (time = Time::Format::HTTP_DATE.parse(time)) > 5.minutes.ago && time < 5.minutes.from_now
        raise Error.new("date out of range")
      end
      true
    end

    def self.verify?(actor, url, headers)
      verify(actor, url, headers)
    rescue Error
      false
    end
  end
end
