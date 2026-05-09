require "../../src/safe/safe_json"

require "../spec_helper/base"

Spectator.describe Ktistec::SafeJSON do
  describe ".from" do
    it "encodes a string" do
      expect(described_class.from("hello").to_s).to eq(%("hello"))
    end

    it "encodes an integer" do
      expect(described_class.from(42).to_s).to eq("42")
    end

    it "encodes a boolean" do
      expect(described_class.from(true).to_s).to eq("true")
    end

    it "encodes an array" do
      expect(described_class.from([1, 2, 3]).to_s).to eq("[1,2,3]")
    end

    it "encodes a hash" do
      expect(described_class.from({"a" => 1}).to_s).to eq(%({"a":1}))
    end

    it "encodes nil" do
      expect(described_class.from(nil).to_s).to eq("null")
    end

    it "escapes < as \\u003c" do
      expect(described_class.from("<").to_s).to eq(%("\\u003c"))
    end

    it "escapes > as \\u003e" do
      expect(described_class.from(">").to_s).to eq(%("\\u003e"))
    end

    it "escapes & as \\u0026" do
      expect(described_class.from("&").to_s).to eq(%("\\u0026"))
    end

    it "neutralizes the </script> early-close" do
      output = described_class.from("</script>").to_s
      expect(output).to_not contain("</")
      expect(output).to eq(%("\\u003c/script\\u003e"))
    end

    it "neutralizes <!-- HTML comment --> confusion" do
      output = described_class.from("<!-- comment -->").to_s
      expect(output).to_not contain("<!")
      expect(output).to_not contain("-->")
      expect(output).to eq(%("\\u003c!-- comment --\\u003e"))
    end

    it "escapes adversarial chars inside nested structures" do
      output = described_class.from({"name" => "Q&A", "tag" => "<em>"}).to_s
      expect(output).to_not contain("<")
      expect(output).to_not contain(">")
      expect(output).to_not contain("&")
      expect(output).to eq(%({"name":"Q\\u0026A","tag":"\\u003cem\\u003e"}))
    end

    it "returns a SafeJSON" do
      expect(described_class.from(1)).to be_a(Ktistec::SafeJSON)
    end
  end

  describe ".assert_safe" do
    it "wraps the string" do
      expect(described_class.assert_safe(%("x")).to_s).to eq(%("x"))
    end

    it "returns a SafeJSON" do
      expect(described_class.assert_safe(%("x"))).to be_a(Ktistec::SafeJSON)
    end
  end

  describe "#to_s" do
    it "returns the wrapped value" do
      expect(described_class.assert_safe(%("hello")).to_s).to eq(%("hello"))
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
      expect(described_class.assert_safe("12345").size).to eq(5)
    end
  end

  describe "#==" do
    context "comparing two SafeJSON instances" do
      it "is true" do
        expect(described_class.assert_safe("x") == described_class.assert_safe("x")).to be_true
      end

      it "is false" do
        expect(described_class.assert_safe("x") == described_class.assert_safe("y")).to be_false
      end
    end

    context "comparing a SafeJSON to a String" do
      it "is true" do
        expect(described_class.assert_safe("x") == "x").to be_true
      end

      it "is false" do
        expect(described_class.assert_safe("x") == "y").to be_false
      end
    end
  end
end
