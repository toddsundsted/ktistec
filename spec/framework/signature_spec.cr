require "../../src/framework/signature"

require "../spec_helper/key_pair"
require "../spec_helper/model"

Spectator.describe Ktistec::Signature do
  setup_spec

  let(key_pair) { KeyPair.new("https://key_pair") }

  describe ".sign" do
    it "returns headers" do
      expect(described_class.sign(key_pair, "https://remote/inbox")).to be_a(HTTP::Headers)
    end

    it "includes a signature" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Signature"]?).not_to be_nil
    end

    it "includes digest header if the body is supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox", body: "body")["Digest"]?).not_to be_nil
    end

    it "does not include digest header if the body is not supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Digest"]?).to be_nil
    end

    it "includes content type header if content type is supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox", content_type: "type")["Content-Type"]?).not_to be_nil
    end

    it "does not include content type header if content type is not supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Content-Type"]?).to be_nil
    end

    it "includes content length header if content length is supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox", content_length: 100)["Content-Length"]?).not_to be_nil
    end

    it "does not include content length header if content length is not supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Content-Length"]?).to be_nil
    end

    it "includes accept header if accept is supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox", accept: "type")["Accept"]?).not_to be_nil
    end

    it "does not include accept header if accept is not supplied" do
      expect(described_class.sign(key_pair, "https://remote/inbox")["Accept"]?).to be_nil
    end

    let(now) { Time.unix(1451703845) }
    let(signature) { described_class.sign(key_pair, "https://remote/inbox", algorithm: algorithm, time: now)["Signature"].split(",") }

    context "with hs2019" do
      let(algorithm) { "hs2019" }

      it "sets the algorithm signature parameter to 'rsa-sha256'" do
        expect(signature).to have(%q<algorithm="hs2019">)
      end

      it "sets the created signature parameter" do
        expect(signature).to have(%q<created=1451703845>)
      end

      it "sets the expires signature parameter" do
        expect(signature).to have(%q<expires=1451704145>)
      end

      it "includes (created) in the headers signature parameter" do
        expect(signature).to have(/ \(created\) /)
      end

      it "includes (expires) in the headers signature parameter" do
        expect(signature).to have(/ \(expires\) /)
      end
    end

    context "with rsa-sha256" do
      let(algorithm) { "rsa-sha256" }

      it "sets the algorithm signature parameter to 'rsa-sha256'" do
        expect(signature).to have(%q<algorithm="rsa-sha256">)
      end

      it "includes date in the headers signature parameter" do
        expect(signature).to have(/ date /)
      end
    end
  end

  describe ".verify" do
    let(headers) { described_class.sign(key_pair, "https://remote/inbox", body: "body", content_type: "type", content_length: 4, accept: "type") }

    it "raises an error if the signature header is not present" do
      expect{described_class.verify(key_pair, "https://remote/inbox", HTTP::Headers.new)}.
        to raise_error(Ktistec::Signature::Error, "missing signature")
    end

    it "raises an error if the signature header is malformed" do
      expect{described_class.verify(key_pair, "https://remote/inbox", HTTP::Headers{"Signature" => ""})}.
        to raise_error(Ktistec::Signature::Error, "malformed signature")
    end

    it "raises an error if the signing keys don't match" do
      key_pair.public_key = OpenSSL::RSA.new("-----BEGIN PUBLIC KEY-----\nMFowDQYJKoZIhvcNAQEBBQADSQAwRgJBAJw6kBEQGSgQVt+T5/8Tq+8235TDi4wx\nziJ107KaI578uAIDoYg6U2ULSpfY4/lUnNH2W9hp6tPMTljY967+PacCARE=\n-----END PUBLIC KEY-----\n", nil, false)
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the host header isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("host", "")
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "host header must be signed")
    end

    it "raises an error if the host doesn't match" do
      expect{described_class.verify(key_pair, "https://foo_bar/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the port doesn't match" do
      expect{described_class.verify(key_pair, "https://remote:8443/inbox", headers, "body")}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    context "given a non-standard port" do
      let(headers) { described_class.sign(key_pair, "https://remote:8443/inbox", body: "body") }

      it "raises an error if the port doesn't match" do
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, "body")}.
          to raise_error(Ktistec::Signature::Error, /invalid signature/)
      end

      it "verifies signature" do
        expect(described_class.verify(key_pair, "https://remote:8443/inbox", headers, "body")).to be_true
      end
    end

    it "raises an error if the (request-target) header isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("(request-target)", "")
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "(request-target) header must be signed")
    end

    it "raises an error if the request target path doesn't match" do
      expect{described_class.verify(key_pair, "https://remote/foo_bar", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the request target method doesn't match" do
      expect{described_class.verify(key_pair, "https://remote/inbox", headers, method: :put)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    context "with hs2019" do
      let(headers) { described_class.sign(key_pair, "https://remote/inbox", algorithm: "hs2019", body: "") }

      it "raises an error if the (created) header isn't signed" do
        headers["Signature"] = headers["Signature"].gsub("(created)", "")
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, "")}.
          to raise_error(Ktistec::Signature::Error, "(created) header must be signed")
      end

      it "raises an error if the (created) header doesn't match" do
        headers["Signature"] = headers["Signature"].gsub(/created=[0-9]+/, "created=BAD DATE")
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, "")}.
          to raise_error(Ktistec::Signature::Error, /invalid signature/)
      end

      it "raises an error if the (expires) header doesn't match" do
        headers["Signature"] = headers["Signature"].gsub(/expires=[0-9]+/, "expires=BAD DATE")
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, "")}.
          to raise_error(Ktistec::Signature::Error, /invalid signature/)
      end

      it "raises an error if date is out of range" do
        headers = described_class.sign(key_pair, "https://remote/inbox", algorithm: "hs2019", time: 10.minutes.from_now, method: :get)
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, method: :get)}.
          to raise_error(Ktistec::Signature::Error, "received before creation date")
      end

      it "raises an error if date is out of range" do
        headers = described_class.sign(key_pair, "https://remote/inbox", algorithm: "hs2019", time: 1.hour.ago, method: :get)
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, method: :get)}.
          to raise_error(Ktistec::Signature::Error, "received after expiration date")
      end

      it "verifies signature" do
        expect(described_class.verify(key_pair, "https://remote/inbox", headers, "")).to be_true
      end
    end

    context "with rsa-sha256" do
      let(headers) { described_class.sign(key_pair, "https://remote/inbox", algorithm: "rsa-sha256", body: "") }

      it "raises an error if the date header isn't signed" do
        headers["Signature"] = headers["Signature"].gsub("date", "")
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, "")}.
          to raise_error(Ktistec::Signature::Error, "date header must be signed")
      end

      it "raises an error if the date header doesn't match" do
        headers["Date"] = "BAD DATE"
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, "")}.
          to raise_error(Ktistec::Signature::Error, /invalid signature/)
      end

      it "raises an error if date is out of range" do
        headers = described_class.sign(key_pair, "https://remote/inbox", algorithm: "rsa-sha256", time: 10.minutes.from_now, method: :get)
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, method: :get)}.
          to raise_error(Ktistec::Signature::Error, "date out of range")
      end

      it "raises an error if date is out of range" do
        headers = described_class.sign(key_pair, "https://remote/inbox", algorithm: "rsa-sha256", time: 1.hour.ago, method: :get)
        expect{described_class.verify(key_pair, "https://remote/inbox", headers, method: :get)}.
          to raise_error(Ktistec::Signature::Error, "date out of range")
      end

      it "verifies signature" do
        expect(described_class.verify(key_pair, "https://remote/inbox", headers, "")).to be_true
      end
    end

    it "raises an error if the digest header isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("digest", "")
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "body digest must be signed")
    end

    it "raises an error if the digest header doesn't match" do
      headers["Digest"] = "BAD DIGEST"
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the body digest doesn't match" do
      expect{described_class.verify(key_pair, "https://remote/inbox", headers, body: "")}.
        to raise_error(Ktistec::Signature::Error, "body doesn't match")
    end

    it "raises an error if the content type header doesn't match" do
      headers["Content-Type"] = "FOO/BAR"
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the content length header doesn't match" do
      headers["Content-Length"] = "100"
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the accept header doesn't match" do
      headers["Accept"] = "FOO/BAR"
      expect{described_class.verify(key_pair, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end
  end
end
