require "./spec_helper"

Spectator.describe Slang::Runtime do
  describe ".emit" do
    let(io) { IO::Memory.new }

    it "emits SafeHTML raw" do
      described_class.emit(io, Ktistec::SafeHTML.assert_safe("<em>bold</em>"))
      expect(io.to_s).to eq("<em>bold</em>")
    end

    it "HTML-escapes a plain String" do
      described_class.emit(io, "<em>bold</em>")
      expect(io.to_s).to eq("&lt;em&gt;bold&lt;/em&gt;")
    end

    it "HTML-escapes the result of .to_s on non-string values" do
      described_class.emit(io, [1, "<a>"])
      expect(io.to_s).to eq("[1, &quot;&lt;a&gt;&quot;]")
    end

    it "emits empty string for nil" do
      described_class.emit(io, nil)
      expect(io.to_s).to eq("")
    end
  end
end
