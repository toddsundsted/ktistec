require "../../../src/framework/signature/rfc9421"

require "../../spec_helper/key_pair"
require "../../spec_helper/base"

# signs a request over an explicit list of components,
# given as name/value pairs, per RFC 9421
private def sign(key_pair, components, created = Time.utc.to_unix, alg = nil)
  names = components.map { |name, _| %Q<"#{name}"> }
  signature_params = %Q<(#{names.join(" ")});created=#{created};keyid="#{key_pair.iri}#main-key">
  signature_params += %Q<;alg="#{alg}"> if alg
  lines = components.map { |name, value| %Q<"#{name}": #{value}> }
  lines << %Q<"@signature-params": #{signature_params}>
  signature_base = lines.join("\n")
  signature = Base64.strict_encode(key_pair.private_key.sign(OpenSSL::Digest.new("SHA256"), signature_base))
  HTTP::Headers{
    "Signature-Input" => "sig1=#{signature_params}",
    "Signature"       => "sig1=:#{signature}:",
  }
end

Spectator.describe Ktistec::Signature::RFC9421 do
  let(key_pair) { KeyPair.new("https://key_pair") }

  describe ".sign" do
    it "returns headers" do
      expect(described_class.sign(key_pair, "https://remote/inbox")).to be_a(HTTP::Headers)
    end

    it "includes a signature" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Signature"]?).not_to be_nil
    end

    it "includes content digest header if the body is supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox", body: "body")["Content-Digest"]?).not_to be_nil
    end

    it "does not include content digest header if the body is not supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Content-Digest"]?).to be_nil
    end

    it "includes content type header if content type is supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox", content_type: "type")["Content-Type"]?).not_to be_nil
    end

    it "does not include content type header if content type is not supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Content-Type"]?).to be_nil
    end

    let(now) { Time.unix(1451703845) }
    let(signature_input) { described_class.sign(key_pair, "https://remote/inbox", time: now)["Signature-Input"].split(";") }

    it "sets the keyid signature parameter" do
      expect(signature_input).to have(%q<keyid="https://key_pair#main-key">)
    end

    it "sets the created signature parameter" do
      expect(signature_input).to have(%q<created=1451703845>)
    end

    it "sets the alg signature parameter to 'rsa-v1_5-sha256'" do
      expect(signature_input).to have(%q<alg="rsa-v1_5-sha256">)
    end

    it "covers @method and @target-uri" do
      expect(signature_input).to have(%q<sig1=("@method" "@target-uri")>)
    end

    context "given a body" do
      let(signature_input) { described_class.sign(key_pair, "https://remote/inbox", body: "body")["Signature-Input"].split(";") }

      it "also covers content-digest" do
        expect(signature_input).to have(%q<sig1=("@method" "@target-uri" "content-digest")>)
      end
    end

    context "given a content type" do
      let(signature_input) { described_class.sign(key_pair, "https://remote/inbox", content_type: "type")["Signature-Input"].split(";") }

      it "also covers content-type" do
        expect(signature_input).to have(%q<sig1=("@method" "@target-uri" "content-type")>)
      end
    end
  end

  describe ".parse" do
    let(headers) { sign(key_pair, [{"@method", "GET"}, {"@target-uri", "https://remote/inbox"}]) }

    it "returns nil if the request isn't signed" do
      expect(described_class.parse(HTTP::Headers.new)).to be_nil
    end

    it "parses the key id" do
      expect(described_class.parse(headers).try(&.key_id)).to eq("https://key_pair#main-key")
    end

    context "given a signature covering a component with parameters" do
      before_each { headers["Signature-Input"] = headers["Signature-Input"].sub(%q<"@method">, %q<"@method";req>) }

      it "returns nil" do
        expect(described_class.parse(headers)).to be_nil
      end
    end

    context "given a signature whose label differs from its input's label" do
      before_each { headers["Signature"] = headers["Signature"].sub("sig1=", "sig2=") }

      it "returns nil" do
        expect(described_class.parse(headers)).to be_nil
      end
    end

    context "given two signatures" do
      before_each do
        headers["Signature-Input"] = headers["Signature-Input"] + %q<, sig2=("@method");created=1;keyid="https://other#main-key">
        headers["Signature"] = headers["Signature"] + ", sig2=:AAAA:"
      end

      it "returns nil" do
        expect(described_class.parse(headers)).to be_nil
      end
    end
  end
end

Spectator.describe Ktistec::Signature::RFC9421::Parsed do
  let(key_pair) { KeyPair.new("https://key_pair") }

  describe "#verify" do
    def verify(key_pair, url, headers, body = nil, method = :post)
      Ktistec::Signature::RFC9421.parse(headers).not_nil!.verify(key_pair, url, headers, body, method)
    end

    let(alg) { nil }
    let(created) { Time.utc.to_unix }
    let(digest) { "sha-256=:#{Base64.strict_encode(OpenSSL::Digest.new("SHA256").update("body").final)}:" }
    let(components) { [{"@method", "POST"}, {"@target-uri", "https://remote/inbox"}, {"content-digest", digest}] }
    let(headers) { sign(key_pair, components, created, alg).tap { |headers| headers["Content-Digest"] = digest } }

    it "verifies a signature over @method, @target-uri, and content-digest" do
      expect(verify(key_pair, "https://remote/inbox", headers, "body")).to be_true
    end

    it "raises an error if the body doesn't match the content digest" do
      expect { verify(key_pair, "https://remote/inbox", headers, "tampered") }.to raise_error(Ktistec::Signature::Error, "body doesn't match")
    end

    it "raises an error if the signature was made for another URL" do
      expect { verify(key_pair, "https://remote/outbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the signature was made for another method" do
      expect { verify(key_pair, "https://remote/inbox", headers, "body", method: :put) }.to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    context "given a signature that isn't base64" do
      before_each { headers["Signature"] = "sig1=:A:" }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "malformed signature")
      end
    end

    context "given a signature that doesn't cover @method" do
      let(components) { [{"@target-uri", "https://remote/inbox"}, {"content-digest", digest}] }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "@method must be signed")
      end
    end

    context "given a signature that doesn't cover @target-uri" do
      let(components) { [{"@method", "POST"}, {"content-digest", digest}] }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "@target-uri must be signed")
      end
    end

    context "given a signature that doesn't cover content-digest" do
      let(components) { [{"@method", "POST"}, {"@target-uri", "https://remote/inbox"}] }

      it "raises an error for a POST" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "body digest must be signed")
      end

      context "and the request is a GET" do
        let(components) { [{"@method", "GET"}, {"@target-uri", "https://remote/inbox"}] }

        it "verifies the signature" do
          expect(verify(key_pair, "https://remote/inbox", headers, method: :get)).to be_true
        end
      end
    end

    context "given a signature without a created parameter" do
      before_each { headers["Signature-Input"] = headers["Signature-Input"].sub(/;created=\d+/, "") }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "created parameter must be specified")
      end
    end

    context "given a signature created more than five minutes in the future" do
      let(created) { 10.minutes.from_now.to_unix }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "created out of range")
      end
    end

    context "given a signature created more than five minutes ago" do
      let(created) { 10.minutes.ago.to_unix }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "created out of range")
      end
    end

    context "given a signature that names rsa-v1_5-sha256 as its algorithm" do
      let(alg) { "rsa-v1_5-sha256" }

      it "verifies the signature" do
        expect(verify(key_pair, "https://remote/inbox", headers, "body")).to be_true
      end
    end

    context "given a signature that names another algorithm" do
      let(alg) { "rsa-pss-sha512" }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "unsupported algorithm: rsa-pss-sha512")
      end
    end

    context "given a signature that covers @authority" do
      let(components) { [{"@method", "POST"}, {"@target-uri", "https://remote/inbox"}, {"@authority", "remote"}, {"content-digest", digest}] }

      it "verifies the signature" do
        expect(verify(key_pair, "https://remote/inbox", headers, "body")).to be_true
      end
    end

    context "given a signature that covers host" do
      let(components) { [{"@method", "POST"}, {"@target-uri", "https://remote/inbox"}, {"host", "remote"}, {"content-digest", digest}] }

      before_each { headers["Host"] = "localhost:3000" }

      it "verifies the signature against the URL's authority, not the request's Host header" do
        expect(verify(key_pair, "https://remote/inbox", headers, "body")).to be_true
      end
    end

    context "given a signature that covers an arbitrary header" do
      let(date) { Time::Format::HTTP_DATE.format(Time.utc) }
      let(components) { [{"@method", "POST"}, {"@target-uri", "https://remote/inbox"}, {"date", date}, {"content-digest", digest}] }

      before_each { headers["Date"] = date }

      it "verifies the signature" do
        expect(verify(key_pair, "https://remote/inbox", headers, "body")).to be_true
      end

      context "but the request lacks the header" do
        before_each { headers.delete("Date") }

        it "raises an error" do
          expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "signed header is missing: date")
        end
      end
    end

    context "given a signature that covers a derived component other than @method, @target-uri, or @authority" do
      let(components) { [{"@method", "POST"}, {"@target-uri", "https://remote/inbox"}, {"@scheme", "https"}, {"content-digest", digest}] }

      it "raises an error" do
        expect { verify(key_pair, "https://remote/inbox", headers, "body") }.to raise_error(Ktistec::Signature::Error, "unsupported component: @scheme")
      end
    end

    context "given a POST signed by .sign" do
      let(headers) { Ktistec::Signature::RFC9421.sign(key_pair, "https://remote/inbox", body: "body", content_type: "type") }

      it "verifies the signature" do
        expect(verify(key_pair, "https://remote/inbox", headers, "body")).to be_true
      end
    end

    context "given a GET signed by .sign" do
      let(headers) { Ktistec::Signature::RFC9421.sign(key_pair, "https://remote/inbox", method: :get) }

      it "verifies the signature" do
        expect(verify(key_pair, "https://remote/inbox", headers, method: :get)).to be_true
      end
    end
  end
end
