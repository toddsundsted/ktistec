require "../spec_helper"
require "yaml"

Spectator.describe Balloon do
  describe "::VERSION" do
    it "should return the version" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "..", "shard.yml")))["version"].as_s
      expect(Balloon::VERSION).to eq(version)
    end
  end

  context "host" do
    before_each { Balloon.database.exec "BEGIN TRANSACTION" }
    after_each { Balloon.database.exec "ROLLBACK" }

    it "raises an error when not set" do
      Balloon.clear_host
      expect{Balloon.host}.to raise_error
    end

    it "returns false when not set" do
      Balloon.clear_host
      expect{Balloon.host?}.to be_false
    end

    it "must specify a scheme" do
      expect{Balloon.host = "test.test"}.to raise_error("scheme must be present")
    end

    it "must specify a host" do
      expect{Balloon.host = "https://"}.to raise_error("host must be present")
    end

    it "must not specify a fragment" do
      expect{Balloon.host = "https://test.test#fragment"}.to raise_error("fragment must not be present")
    end

    it "must not specify a query" do
      expect{Balloon.host = "https://test.test?query"}.to raise_error("query must not be present")
    end

    it "must not specify a path" do
      expect{Balloon.host = "https://test.test/path"}.to raise_error("path must not be present")
    end

    it "returns the host" do
      expect(Balloon.host).to eq("https://test.test")
    end

    it "updates the database" do
      Balloon.host = "https://test.test"
      expect(Balloon.database.scalar("SELECT value FROM options WHERE key = ?", "host")).to eq("https://test.test")
    end

    it "updates the database" do
      Balloon.host = "https://test.test/"
      expect(Balloon.database.scalar("SELECT value FROM options WHERE key = ?", "host")).to eq("https://test.test")
    end

    it "returns the host" do
      expect(Balloon.host).to eq("https://test.test")
    end
  end
end
