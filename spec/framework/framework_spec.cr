require "yaml"

require "../spec_helper/base"

require "../../src/framework"

Spectator.describe Ktistec do
  describe "::VERSION" do
    it "should return the version" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "..", "shard.yml")))["version"].as_s
      expect(Ktistec::VERSION).to eq(version)
    end
  end

  context "host" do
    setup_spec

    it "raises an error when not set" do
      Ktistec.clear_host
      expect{Ktistec.host}.to raise_error
    end

    it "returns false when not set" do
      Ktistec.clear_host
      expect{Ktistec.host?}.to be_false
    end

    it "must specify a scheme" do
      expect{Ktistec.host = "test.test"}.to raise_error("scheme must be present")
    end

    it "must specify a host" do
      expect{Ktistec.host = "https://"}.to raise_error("host must be present")
    end

    it "must not specify a fragment" do
      expect{Ktistec.host = "https://test.test#fragment"}.to raise_error("fragment must not be present")
    end

    it "must not specify a query" do
      expect{Ktistec.host = "https://test.test?query"}.to raise_error("query must not be present")
    end

    it "must not specify a path" do
      expect{Ktistec.host = "https://test.test/path"}.to raise_error("path must not be present")
    end

    it "updates the database" do
      Ktistec.clear_host
      Ktistec.host = "https://test.test/"
      expect(Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "host")).to eq("https://test.test")
    end

    it "returns the host" do
      expect(Ktistec.host).to eq("https://test.test")
    end
  end

  context "site" do
    setup_spec

    it "raises an error when not set" do
      Ktistec.clear_site
      expect{Ktistec.site}.to raise_error
    end

    it "returns false when not set" do
      Ktistec.clear_site
      expect{Ktistec.site?}.to be_false
    end

    it "must be present" do
      expect{Ktistec.site = ""}.to raise_error("must be present")
    end

    it "updates the database" do
      Ktistec.clear_site
      Ktistec.site = "Ktistec"
      expect(Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "site")).to eq("Ktistec")
    end

    it "returns the site" do
      expect(Ktistec.site).to eq("Ktistec")
    end
  end
end
