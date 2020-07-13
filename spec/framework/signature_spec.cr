require "../spec_helper"

Spectator.describe Balloon::Signature do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let(actor) { register(with_keys: true).actor.save }

  describe ".sign" do
    it "generates a signature" do
      expect(described_class.sign(actor, "https://remote/inbox")).to be_a(HTTP::Headers)
    end
  end

  describe ".verify" do
    let(headers) { described_class.sign(actor, "https://remote/inbox") }

    it "raises an error if the signature header is not present" do
      expect{described_class.verify(actor, "https://remote/inbox", HTTP::Headers.new)}.to raise_error(Balloon::Signature::Error, "missing signature")
    end

    it "raises an error if the signature header is malformed" do
      expect{described_class.verify(actor, "https://remote/inbox", HTTP::Headers{"Signature" => ""})}.to raise_error(Balloon::Signature::Error, "malformed signature")
    end

    it "raises an error if the actor didn't generate the signature" do
      expect{described_class.verify(ActivityPub::Actor.new, "https://remote/inbox", headers)}.to raise_error(Balloon::Signature::Error, "invalid keyId")
    end

    it "raises an error if the keys don't match" do
      expect{described_class.verify(actor.assign(pem_public_key: "-----BEGIN PUBLIC KEY-----\nMFowDQYJKoZIhvcNAQEBBQADSQAwRgJBAJw6kBEQGSgQVt+T5/8Tq+8235TDi4wx\nziJ107KaI578uAIDoYg6U2ULSpfY4/lUnNH2W9hp6tPMTljY967+PacCARE=\n-----END PUBLIC KEY-----\n"), "https://remote/inbox", headers)}.to raise_error(Balloon::Signature::Error, "invalid signature")
    end

    it "raises an error if the host doesn't match" do
      expect{described_class.verify(actor, "https://foo_bar/inbox", headers)}.to raise_error(Balloon::Signature::Error, "invalid signature")
    end

    it "raises an error if the path doesn't match" do
      expect{described_class.verify(actor, "https://remote/foo_bar", headers)}.to raise_error(Balloon::Signature::Error, "invalid signature")
    end

    it "raises an error if the date is out of range" do
      expect{described_class.verify(actor, "https://remote/inbox", described_class.sign(actor, "https://remote/inbox", 1.hour.ago))}.to raise_error(Balloon::Signature::Error, "date out of range")
    end

    it "verifies a signature" do
      expect(described_class.verify(actor, "https://remote/inbox", headers)).to be_true
    end
  end
end
