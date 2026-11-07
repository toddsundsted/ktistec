require "../signature"

module Ktistec
  # HTTP Message Signatures (https://www.rfc-editor.org/rfc/rfc9421)
  # support.
  #
  # Supports the profile in use on the Fediverse: one signature over
  # derived components and header fields, signed with `rsa-v1_5-sha256`.
  # Rejects everything else.
  #
  module Signature::RFC9421
    extend self

    def sign(key_pair, url, body = nil, content_type = nil, method = :post, time = Time.utc)
      key = key_pair.private_key.not_nil!
      url = URI.parse(url).normalize
      components = %q<"@method" "@target-uri">
      signature_base = %Q<"@method": #{method.to_s.upcase}\n"@target-uri": #{url}>
      headers = HTTP::Headers.new
      if body
        digest = "sha-256=:" + Base64.strict_encode(OpenSSL::Digest.new("SHA256").update(body).final) + ":"
        components += %q< "content-digest">
        signature_base += %Q<\n"content-digest": #{digest}>
        headers["Content-Digest"] = digest
      end
      if content_type
        components += %q< "content-type">
        signature_base += %Q<\n"content-type": #{content_type}>
        headers["Content-Type"] = content_type
      end
      signature_params = %Q<(#{components});created=#{time.to_unix};keyid="#{key_pair.iri}#main-key";alg="rsa-v1_5-sha256">
      signature_base += %Q<\n"@signature-params": #{signature_params}>
      signature = Base64.strict_encode(key.sign(OpenSSL::Digest.new("SHA256"), signature_base))
      headers["Signature-Input"] = "sig1=#{signature_params}"
      headers["Signature"] = "sig1=:#{signature}:"
      headers
    end

    # A parsed `Signature` and `Signature-Input` header pair.
    #
    struct Parsed
      def initialize(@components : Array(String), @parameters : Hash(String, String), @signature_params : String, @signature : String)
      end

      def key_id
        @parameters["keyid"]?
      end

      def verify(key_pair, url, headers, body = nil, method = :post)
        url = URI.parse(url).normalize
        if (alg = @parameters["alg"]?) && alg != "rsa-v1_5-sha256"
          raise Error.new("unsupported algorithm: #{alg}")
        end
        unless "@method".in?(@components)
          raise Error.new("@method must be signed")
        end
        unless "@target-uri".in?(@components)
          raise Error.new("@target-uri must be signed")
        end
        unless method != :post || "content-digest".in?(@components)
          raise Error.new("body digest must be signed")
        end
        unless (created = @parameters["created"]?.try(&.to_i64?))
          raise Error.new("created parameter must be specified")
        end
        signature_base =
          @components.map do |component|
            case component
            when "@method"
              %Q<"#{component}": #{method.to_s.upcase}>
            when "@target-uri"
              %Q<"#{component}": #{url}>
            when "@authority"
              %Q<"#{component}": #{url.authority}>
            when .starts_with?("@")
              raise Error.new("unsupported component: #{component}")
            when "host"
              # the host comes from the URL, not the request
              %Q<"#{component}": #{url.authority}>
            else
              unless (values = headers.get?(component))
                raise Error.new("signed header is missing: #{component}")
              end
              %Q<"#{component}": #{values.map(&.strip).join(", ")}>
            end
          end.push(%Q<"@signature-params": #{@signature_params}>).join("\n")
        decoded =
          begin
            Base64.decode(@signature)
          rescue Base64::Error
            raise Error.new("malformed signature")
          end
        key = key_pair.public_key
        unless key.try(&.verify(OpenSSL::Digest.new("SHA256"), decoded, signature_base))
          raise Error.new("invalid signature: signed by keyid=#{@parameters["keyid"]?}")
        end
        # five minutes of leeway for clock skew
        unless created > 5.minutes.ago.to_unix && created < 5.minutes.from_now.to_unix
          raise Error.new("created out of range")
        end
        if "content-digest".in?(@components)
          digest = "sha-256=:" + Base64.strict_encode(OpenSSL::Digest.new("SHA256").update(body.not_nil!).final) + ":"
          unless headers["Content-Digest"]? == digest
            raise Error.new("body doesn't match")
          end
        end
        true
      end
    end

    private KEY = %q<[a-z*][a-z0-9_\-.*]*>

    private STRING = %q<"[^"\\]*">

    private SIGNATURE_INPUT = /\A(#{KEY})=(\(((?:#{STRING}(?: #{STRING})*)?)\)((?:;#{KEY}=(?:#{STRING}|-?\d{1,15}))*))\z/

    private SIGNATURE = /\A(#{KEY})=:([A-Za-z0-9+\/]*={0,2}):\z/

    def parse(headers)
      if (input = headers["Signature-Input"]?.try(&.match(SIGNATURE_INPUT))) && (signature = headers["Signature"]?.try(&.match(SIGNATURE))) && input[1] == signature[1]
        components = input[3].scan(/"([^"]*)"/).map(&.[1])
        parameters = input[4].scan(/;(#{KEY})=(?:"([^"]*)"|(-?\d+))/).reduce({} of String => String) do |a, m|
          a[m[1]] = m[2]? || m[3]
          a
        end
        Parsed.new(components, parameters, input[2], signature[2])
      end
    end
  end
end
