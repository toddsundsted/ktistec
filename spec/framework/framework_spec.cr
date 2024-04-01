require "yaml"

require "../../src/framework"

require "../spec_helper/base"

Spectator.describe Ktistec::LogLevel do
  setup_spec

  describe "#save" do
    let!(log_level) { described_class.new("foo.bar", :debug) }

    pre_condition { expect(described_class.all_as_hash).to be_empty }

    it "persists the instance to the database" do
      log_level.save
      expect(Ktistec::LogLevel.all_as_hash).to eq({"foo.bar" => log_level})
    end
  end

  describe "#destroy" do
    let!(log_level) { described_class.new("foo.bar", :debug).save }

    pre_condition { expect(described_class.all_as_hash).to eq({"foo.bar" => log_level}) }

    it "removes the instance from the database" do
      log_level.destroy
      expect(Ktistec::LogLevel.all_as_hash).to be_empty
    end
  end

  describe "#all_as_hash" do
    let!(bar) { described_class.new("foo.bar", :debug).save }
    let!(baz) { described_class.new("foo.baz", :error).save }
    let!(qux) { described_class.new("foo.qux", :fatal).save }

    it "returns all log levels as a hash" do
      expect(described_class.all_as_hash).to eq({
        "foo.bar" => bar,
        "foo.baz" => baz,
        "foo.qux" => qux
      })
    end
  end
end

Spectator.describe Ktistec::Settings do
  setup_spec

  subject { Ktistec.settings }

  after_each do
    # reset settings to initial values
    Ktistec.settings.assign({"host" => "https://test.test/", "site" => "Test", "footer" => nil}).save
  end

  it "initializes instance from the persisted values" do
    Ktistec.clear_settings

    Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", "host", "HOST")
    Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", "site", "SITE")
    Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", "footer", "FOOTER")

    expect(subject.host).to eq("HOST")
    expect(subject.site).to eq("SITE")
    expect(subject.footer).to eq("FOOTER")
  end

  describe "#save" do
    it "persists assigned values to the database" do
      subject.assign({"host" => "https://test.test/", "site" => "Test", "footer" => "Copyright"}).save

      expect(Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "host")).to eq("https://test.test")
      expect(Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "site")).to eq("Test")
      expect(Ktistec.database.scalar("SELECT value FROM options WHERE key = ?", "footer")).to eq("Copyright")
    end
  end

  describe "#assign" do
    it "sets the host" do
      subject.clear_host
      expect{subject.assign({"host" => "HOST"})}.to change{subject.host}
    end

    it "sets the site" do
      subject.clear_site
      expect{subject.assign({"site" => "SITE"})}.to change{subject.site}
    end

    it "sets the footer" do
      subject.clear_footer
      expect{subject.assign({"footer" => "FOOTER"})}.to change{subject.footer}
    end
  end

  describe "#valid?" do
    it "expects host to be present" do
      expect(subject.assign({"host" => ""}).valid?).to be_false
      expect(subject.errors["host"]).to contain("name must be present")
    end

    it "expects host to specify a scheme" do
      expect(subject.assign({"host" => "test.test"}).valid?).to be_false
      expect(subject.errors["host"]).to contain("must have a scheme")
    end

    it "expects host to specify a host name" do
      expect(subject.assign({"host" => "test.test"}).valid?).to be_false
      expect(subject.errors["host"]).not_to contain("must have a host name")
    end

    it "expects host to specify a host name" do
      expect(subject.assign({"host" => "test.test"}).valid?).to be_false
      expect(subject.errors["host"]).not_to contain("must not have a path")
    end

    it "expects host to specify a host name" do
      expect(subject.assign({"host" => "https://"}).valid?).to be_false
      expect(subject.errors["host"]).to contain("must have a host name")
    end

    it "expects host not to specify a fragment" do
      expect(subject.assign({"host" => "https://test.test#fragment"}).valid?).to be_false
      expect(subject.errors["host"]).to contain("must not have a fragment")
    end

    it "expects hosts not to specify a query" do
      expect(subject.assign({"host" => "https://test.test?query"}).valid?).to be_false
      expect(subject.errors["host"]).to contain("must not have a query")
    end

    it "expects host not to specify a path" do
      expect(subject.assign({"host" => "https://test.test/path"}).valid?).to be_false
      expect(subject.errors["host"]).to contain("must not have a path")
    end

    it "expects site to be present" do
      expect(subject.assign({"site" => ""}).valid?).to be_false
      expect(subject.errors["site"]).to contain("name must be present")
    end
  end
end

Spectator.describe Ktistec do
  describe "::VERSION" do
    it "should return the version" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "..", "shard.yml")))["version"].as_s
      expect(Ktistec::VERSION).to eq(version)
    end
  end

  describe ".settings" do
    it "returns the settings singleton" do
      expect(Ktistec.settings).to be_a(Ktistec::Settings)
    end

    context "given previous errors" do
      before_each { Ktistec.settings.errors["settings"] = ["has an error"] }

      it "clears the errors when getting the settings singleton" do
        expect(Ktistec.settings.errors).to be_empty
      end
    end
  end

  context "given initialized settings" do
    before_each do
      Ktistec.settings.assign({"host" => "https://test.test/", "site" => "Test", "footer" => "Copyright"}).save
    end

    describe ".host" do
      it "returns the host" do
        expect(Ktistec.host).to eq("https://test.test")
      end
    end

    describe ".site" do
      it "returns the site" do
        expect(Ktistec.site).to eq("Test")
      end
    end

    describe ".footer" do
      it "returns the footer" do
        expect(Ktistec.footer).to eq("Copyright")
      end
    end
  end
end
