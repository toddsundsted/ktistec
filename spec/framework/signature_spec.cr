require "../../src/framework/signature"

require "../spec_helper/model"
require "../spec_helper/register"

Spectator.describe Ktistec::Signature do
  setup_spec

  let(actor) { register(with_keys: true).actor.save }

  describe ".sign" do
    it "returns headers" do
      expect(described_class.sign(actor, "https://remote/inbox")).to be_a(HTTP::Headers)
    end

    it "includes a signature" do
      expect(described_class.sign(actor, "https://remote/inbox")["Signature"]?).not_to be_nil
    end

    it "includes digest header if the body is supplied" do
      expect(described_class.sign(actor, "https://remote/inbox", body: "body")["Digest"]?).not_to be_nil
    end

    it "does not include digest header if the body is not supplied" do
      expect(described_class.sign(actor, "https://remote/inbox")["Digest"]?).to be_nil
    end

    it "includes content type header if content type is supplied" do
      expect(described_class.sign(actor, "https://remote/inbox", content_type: "type")["Content-Type"]?).not_to be_nil
    end

    it "does not include content type header if content type is not supplied" do
      expect(described_class.sign(actor, "https://remote/inbox")["Content-Type"]?).to be_nil
    end
  end

  describe ".verify" do
    let(headers) { described_class.sign(actor, "https://remote/inbox", body: "body", content_type: "type") }

    it "raises an error if the signature header is not present" do
      expect{described_class.verify(actor, "https://remote/inbox", HTTP::Headers.new)}.
        to raise_error(Ktistec::Signature::Error, "missing signature")
    end

    it "raises an error if the signature header is malformed" do
      expect{described_class.verify(actor, "https://remote/inbox", HTTP::Headers{"Signature" => ""})}.
        to raise_error(Ktistec::Signature::Error, "malformed signature")
    end

    it "raises an error if the signing keys don't match" do
      expect{described_class.verify(actor.assign(pem_public_key: "-----BEGIN PUBLIC KEY-----\nMFowDQYJKoZIhvcNAQEBBQADSQAwRgJBAJw6kBEQGSgQVt+T5/8Tq+8235TDi4wx\nziJ107KaI578uAIDoYg6U2ULSpfY4/lUnNH2W9hp6tPMTljY967+PacCARE=\n-----END PUBLIC KEY-----\n"), "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the host header isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("host", "")
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "host header must be signed")
    end

    it "raises an error if the host doesn't match" do
      expect{described_class.verify(actor, "https://foo_bar/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the request target isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("(request-target)", "")
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "request target must be signed")
    end

    it "raises an error if the path doesn't match" do
      expect{described_class.verify(actor, "https://remote/foo_bar", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the method doesn't match" do
      expect{described_class.verify(actor, "https://remote/inbox", headers, method: :put)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the date header isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("date", "")
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "date header must be signed")
    end

    it "raises an error if the date header doesn't match" do
      headers["Date"] = "BAD DATE"
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the date is out of range" do
      expect{described_class.verify(actor, "https://remote/inbox", described_class.sign(actor, "https://remote/inbox", time: 1.hour.ago, method: :get), method: :get)}.
        to raise_error(Ktistec::Signature::Error, "date out of range")
    end

    it "raises an error if the digest header isn't signed" do
      headers["Signature"] = headers["Signature"].gsub("digest", "")
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, "body digest must be signed")
    end

    it "raises an error if the digest header doesn't match" do
      headers["Digest"] = "BAD DIGEST"
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "raises an error if the body digest doesn't match" do
      expect{described_class.verify(actor, "https://remote/inbox", headers, body: "")}.
        to raise_error(Ktistec::Signature::Error, "body doesn't match")
    end

    it "raises an error if the content type header doesn't match" do
      headers["Content-Type"] = "FOO/BAR"
      expect{described_class.verify(actor, "https://remote/inbox", headers)}.
        to raise_error(Ktistec::Signature::Error, /invalid signature/)
    end

    it "verifies signature" do
      expect(described_class.verify(actor, "https://remote/inbox", headers, "body")).to be_true
    end
  end
end
