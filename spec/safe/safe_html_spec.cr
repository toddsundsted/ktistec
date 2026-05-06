require "../../src/safe/safe_html"

require "../spec_helper/base"

Spectator.describe Ktistec::SafeHTML do
  describe ".escape" do
    it "encodes angle brackets" do
      expect(described_class.escape("<script>").to_s).to eq("&lt;script&gt;")
    end

    it "encodes ampersands" do
      expect(described_class.escape("a & b").to_s).to eq("a &amp; b")
    end

    it "encodes double quotes" do
      expect(described_class.escape(%(a"b)).to_s).to eq("a&quot;b")
    end

    it "encodes single quotes" do
      expect(described_class.escape("a'b").to_s).to eq("a&#39;b")
    end

    it "leaves safe characters alone" do
      expect(described_class.escape("hello world").to_s).to eq("hello world")
    end

    it "returns empty string for nil" do
      expect(described_class.escape(nil).to_s).to eq("")
    end

    it "returns a SafeHTML" do
      expect(described_class.escape("x")).to be_a(Ktistec::SafeHTML)
    end
  end

  describe ".sanitize" do
    it "preserves allowed markup" do
      expect(described_class.sanitize("<em>bold</em>").to_s).to eq("<em>bold</em>")
    end

    it "strips disallowed tags" do
      expect(described_class.sanitize("<script>alert(1)</script>").to_s).to eq("")
    end

    it "returns empty string for nil" do
      expect(described_class.sanitize(nil).to_s).to eq("")
    end

    it "returns a SafeHTML" do
      expect(described_class.sanitize("x")).to be_a(Ktistec::SafeHTML)
    end
  end

  describe ".assert_safe" do
    it "wraps the string" do
      expect(described_class.assert_safe("<em>bold</em>").to_s).to eq("<em>bold</em>")
    end

    it "returns a SafeHTML" do
      expect(described_class.assert_safe("x")).to be_a(Ktistec::SafeHTML)
    end
  end

  describe "#to_s" do
    it "returns the wrapped value" do
      expect(described_class.assert_safe("hello").to_s).to eq("hello")
    end
  end

  describe "#presence" do
    it "returns the wrapped value" do
      expect(described_class.assert_safe("x").presence).to eq("x")
    end

    it "returns nil when blank" do
      expect(described_class.assert_safe("   ").presence).to be_nil
    end
  end

  describe "#empty?" do
    it "is true for empty wrapped value" do
      expect(described_class.assert_safe("").empty?).to be_true
    end

    it "is false for non-empty wrapped value" do
      expect(described_class.assert_safe("x").empty?).to be_false
    end
  end

  describe "#size" do
    it "returns the wrapped value's size" do
      expect(described_class.assert_safe("hello").size).to eq(5)
    end
  end

  describe "#==" do
    context "comparing two SafeHTML instances" do
      it "is true" do
        expect(described_class.assert_safe("x") == described_class.assert_safe("x")).to be_true
      end

      it "is false" do
        expect(described_class.assert_safe("x") == described_class.assert_safe("y")).to be_false
      end
    end

    context "comparing a SafeHTML to a String" do
      it "is true" do
        expect(described_class.assert_safe("x") == "x").to be_true
      end

      it "is false" do
        expect(described_class.assert_safe("x") == "y").to be_false
      end
    end
  end
end
