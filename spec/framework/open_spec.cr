require "../../src/framework/open"

require "../spec_helper/network"

Spectator.describe Ktistec::Open do
  describe ".open" do
    it "fetches the page" do
      expect(described_class.open("https://external/specified-page").body).to eq("content")
    end

    it "follows redirects to page" do
      expect(described_class.open("https://external/redirected-page").body).to eq("content")
    end

    it "fails on errors" do
      expect{described_class.open("https://external/returns-401")}.to raise_error(Ktistec::Open::Error, /Access denied/)
    end

    it "fails on errors" do
      expect{described_class.open("https://external/returns-500")}.to raise_error(Ktistec::Open::Error, /Server error/)
    end

    it "fails on errors" do
      expect{described_class.open("https://external/socket-addrinfo-error")}.to raise_error(Ktistec::Open::Error, /Hostname lookup failure/)
    end

    it "fails on errors" do
      expect{described_class.open("https://external/socket-connect-error")}.to raise_error(Ktistec::Open::Error, /Connection failure/)
    end
  end

  describe ".open?" do
    it "returns nil on errors" do
      expect{described_class.open?("https://external/returns-500")}.to be_nil
    end
  end
end
