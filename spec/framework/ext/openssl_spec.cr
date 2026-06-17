require "../../../src/framework/ext/openssl"

require "../../spec_helper/base"

Spectator.describe OpenSSL::RSA do
  subject { described_class.generate(512, 17) }

  describe ".generate" do
    it "yields a private key" do
      expect(subject.private?).to be_true
    end
  end

  describe "#public_key" do
    it "yields a key that is not private" do
      expect(subject.public_key.private?).to be_false
    end
  end

  describe "#to_pem" do
    it "serializes a private key as a private key" do
      expect(subject.to_pem).to contain("BEGIN PRIVATE KEY")
    end

    it "serializes a public key as a public key" do
      expect(subject.public_key.to_pem).to contain("BEGIN PUBLIC KEY")
    end
  end

  describe ".new" do
    it "parses a serialized private key as a private key" do
      expect(described_class.new(subject.to_pem, true).private?).to be_true
    end

    it "parses a serialized public key as a non-private key" do
      expect(described_class.new(subject.public_key.to_pem, false).private?).to be_false
    end

    it "raises an error on malformed input on the private path" do
      expect { described_class.new("-----BEGIN PRIVATE KEY-----\nbogus\n-----END PRIVATE KEY-----\n", true) }
        .to raise_error(OpenSSL::Error)
    end

    it "raises an error on malformed input on the public path" do
      expect { described_class.new("-----BEGIN PUBLIC KEY-----\nbogus\n-----END PUBLIC KEY-----\n", false) }
        .to raise_error(OpenSSL::Error)
    end

    # a remote actor's key comes off the wire and isn't guaranteed to end in a
    # newline or use LF endings

    it "parses a public key with no trailing newline" do
      pem = subject.public_key.to_pem.rstrip("\n")
      expect(described_class.new(pem, false).private?).to be_false
    end

    it "parses a public key with trailing CRLF line ending" do
      pem = subject.public_key.to_pem.gsub("\n", "\r\n")
      expect(described_class.new(pem, false).private?).to be_false
    end
  end

  let(digest) { OpenSSL::Digest.new("SHA256") }
  let(data) { "the quick brown fox jumps over the lazy dog" }

  describe "#sign" do
    it "raises an error when signing with a public key" do
      expect { subject.public_key.sign(digest, data) }
        .to raise_error(OpenSSL::Error)
    end
  end

  describe "#verify" do
    let(signature) { subject.sign(OpenSSL::Digest.new("SHA256"), data) }

    context "given the signer's public key and the original message" do
      let(verifying_key) { subject.public_key }
      let(message) { data }

      it "verifies" do
        expect(verifying_key.verify(OpenSSL::Digest.new("SHA256"), signature, message)).to be_true
      end

      context "but the public key belongs to a different signer" do
        let(verifying_key) { described_class.generate(512, 17).public_key }

        it "does not verify" do
          expect(verifying_key.verify(OpenSSL::Digest.new("SHA256"), signature, message)).to be_false
        end
      end

      context "but the message was tampered" do
        let(message) { data + "!" }

        it "does not verify" do
          expect(verifying_key.verify(OpenSSL::Digest.new("SHA256"), signature, message)).to be_false
        end
      end
    end

    it "verifies after the public key is round-tripped" do
      round_tripped = described_class.new(subject.public_key.to_pem, false)
      expect(round_tripped.verify(OpenSSL::Digest.new("SHA256"), signature, data)).to be_true
    end
  end
end
