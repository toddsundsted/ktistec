require "../../src/safe/safe_uri"

require "../spec_helper/base"

Spectator.describe Ktistec::SafeURI do
  describe ".from?" do
    context "schemes on the allowlist" do
      it "accepts http" do
        expect(described_class.from?("http://example.com/")).not_to be_nil
      end

      it "accepts https" do
        expect(described_class.from?("https://example.com/")).not_to be_nil
      end

      it "accepts mailto" do
        expect(described_class.from?("mailto:alice@example.com")).not_to be_nil
      end

      it "accepts tel" do
        expect(described_class.from?("tel:+15551234567")).not_to be_nil
      end

      it "accepts magnet" do
        expect(described_class.from?("magnet:?xt=urn:btih:abcdef&dn=example")).not_to be_nil
      end

      it "accepts wss" do
        expect(described_class.from?("wss://tracker.example/socket")).not_to be_nil
      end

      it "accepts at" do
        expect(described_class.from?("at://did:plc:abc/app.bsky.feed.post/123")).not_to be_nil
      end

      it "accepts did" do
        expect(described_class.from?("did:plc:abc")).not_to be_nil
      end

      it "is case-insensitive" do
        expect(described_class.from?("HTTPS://example.com/")).not_to be_nil
      end
    end

    context "schemes not on the allowlist" do
      it "rejects javascript" do
        expect(described_class.from?("javascript:alert(1)")).to be_nil
      end

      it "rejects data" do
        expect(described_class.from?("data:text/html,<script>alert(1)</script>")).to be_nil
      end

      it "rejects vbscript" do
        expect(described_class.from?("vbscript:msgbox(1)")).to be_nil
      end

      it "rejects file" do
        expect(described_class.from?("file:///etc/passwd")).to be_nil
      end

      it "rejects blob" do
        expect(described_class.from?("blob:https://example.com/abc")).to be_nil
      end

      it "rejects mixed-case" do
        expect(described_class.from?("JavaScript:alert(1)")).to be_nil
      end
    end

    context "controls and whitespace" do
      it "rejects embedded newline" do
        expect(described_class.from?("java\nscript:alert(1)")).to be_nil
      end

      it "rejects embedded carriage return" do
        expect(described_class.from?("java\rscript:alert(1)")).to be_nil
      end

      it "rejects embedded tab" do
        expect(described_class.from?("java\tscript:alert(1)")).to be_nil
      end

      it "rejects embedded space" do
        expect(described_class.from?("java script:alert(1)")).to be_nil
      end

      it "rejects DEL" do
        expect(described_class.from?("java\x7fscript:alert(1)")).to be_nil
      end

      it "rejects leading NUL" do
        expect(described_class.from?("\x00javascript:alert(1)")).to be_nil
      end

      it "rejects embedded NUL" do
        expect(described_class.from?("https://example.com/\x00/path")).to be_nil
      end

      it "rejects leading whitespace" do
        expect(described_class.from?(" https://example.com/")).to be_nil
      end
    end

    context "relative references" do
      it "accepts path-absolute" do
        expect(described_class.from?("/relative/path")).not_to be_nil
      end

      it "accepts path-relative" do
        expect(described_class.from?("foo/bar")).not_to be_nil
      end

      it "accepts query-only" do
        expect(described_class.from?("?key=value")).not_to be_nil
      end

      it "accepts fragment-only" do
        expect(described_class.from?("#section")).not_to be_nil
      end

      it "accepts empty" do
        expect(described_class.from?("")).not_to be_nil
      end
    end

    context "protocol-relative references" do
      it "rejects //host/path" do
        expect(described_class.from?("//example.com/path")).to be_nil
      end

      it "rejects //host" do
        expect(described_class.from?("//example.com")).to be_nil
      end

      it "rejects backslash-prefixed protocol-relative references" do
        expect(described_class.from?("\\\\evil.com/path")).to be_nil
        expect(described_class.from?("\\\\evil.com")).to be_nil
      end

      it "rejects mixed-slash protocol-relative references" do
        expect(described_class.from?("/\\evil.com/path")).to be_nil
        expect(described_class.from?("\\/evil.com/path")).to be_nil
      end
    end

    it "returns a SafeURI" do
      expect(described_class.from?("/x")).to be_a(Ktistec::SafeURI)
    end
  end

  describe ".from" do
    it "wraps a valid URI" do
      expect(described_class.from("/x").to_s).to eq("/x")
    end

    it "raises on invalid URI" do
      expect { described_class.from("javascript:alert(1)") }.to raise_error(ArgumentError, /not a safe URI/)
    end

    it "returns a SafeURI" do
      expect(described_class.from("/x")).to be_a(Ktistec::SafeURI)
    end
  end

  describe ".assert_safe" do
    it "wraps the string without validation" do
      expect(described_class.assert_safe("javascript:alert(1)").to_s).to eq("javascript:alert(1)")
    end

    it "returns a SafeURI" do
      expect(described_class.assert_safe("javascript:alert(1)")).to be_a(Ktistec::SafeURI)
    end
  end

  describe "#to_s" do
    it "returns the wrapped value" do
      expect(described_class.assert_safe("/path?q=1").to_s).to eq("/path?q=1")
    end
  end

  describe "#presence" do
    it "returns self when non-blank" do
      uri = described_class.assert_safe("/x")
      expect(uri.presence).to eq(uri)
    end

    it "returns nil when blank" do
      expect(described_class.assert_safe("").presence).to be_nil
    end
  end

  describe "#empty?" do
    it "is true for empty wrapped value" do
      expect(described_class.assert_safe("").empty?).to be_true
    end

    it "is false for non-empty wrapped value" do
      expect(described_class.assert_safe("/x").empty?).to be_false
    end
  end

  describe "#size" do
    it "returns the wrapped value's size" do
      expect(described_class.assert_safe("/abc").size).to eq(4)
    end
  end

  describe "#==" do
    context "comparing two SafeURI instances" do
      it "is true" do
        expect(described_class.assert_safe("/x") == described_class.assert_safe("/x")).to be_true
      end

      it "is false" do
        expect(described_class.assert_safe("/x") == described_class.assert_safe("/y")).to be_false
      end
    end

    context "comparing a SafeURI to a String" do
      it "is true" do
        expect(described_class.assert_safe("/x") == "/x").to be_true
      end

      it "is false" do
        expect(described_class.assert_safe("/x") == "/y").to be_false
      end
    end
  end
end
