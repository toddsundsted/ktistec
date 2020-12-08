require "../spec_helper/network"

require "../../src/framework/open"

Spectator.describe Ktistec::Open do
  describe ".open" do
    it "fetches the specified page" do
      expect(described_class.open("https://external/specified-page").body).to eq("content")
    end

    it "follows redirects" do
      expect(described_class.open("https://external/redirected-page").body).to eq("content")
    end

    it "fails on errors" do
      expect{described_class.open("https://external/returns-500")}.to raise_error(Ktistec::Open::Error)
    end
  end

  describe ".open?" do
    it "returns nil on errors" do
      expect{described_class.open?("https://external/returns-500")}.to be_nil
    end
  end
end
