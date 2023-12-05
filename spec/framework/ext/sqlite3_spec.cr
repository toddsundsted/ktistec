require "../../../src/framework/ext/sqlite3"

require "../../spec_helper/base"

Spectator.describe "SQLite3 extensions" do
  let(key) { random_string }

  context "given an array" do
    it "deserializes a read" do
      Ktistec.database.exec(%Q|INSERT INTO options (key, value) VALUES ("#{key}", "[""one"",""two""]")|)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(Array(String)).new.tap do |r|
        rs.each do
          r << rs.read(Array(String))
        end
      end
      expect(r).to eq([["one", "two"]])
    end

    it "serializes a write" do
      Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, ["one", "two"])
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(String).new.tap do |r|
        rs.each do
          r << rs.read(String)
        end
      end
      expect(r).to eq([%q|["one","two"]|])
    end
  end

  class FooBar
    include JSON::Serializable

    property foo_bar = 1

    def_equals_and_hash(:foo_bar)

    def initialize
    end
  end

  subject { FooBar.new }

  context "given JSON" do
    it "deserializes a read" do
      Ktistec.database.exec(%Q|INSERT INTO options (key, value) VALUES ("#{key}", "{""foo_bar"":1}")|)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(FooBar).new.tap do |r|
        rs.each do
          r << rs.read(FooBar)
        end
      end
      expect(r).to eq([subject])
    end

    it "serializes a write" do
      Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, subject)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(String).new.tap do |r|
        rs.each do
          r << rs.read(String)
        end
      end
      expect(r).to eq([%q|{"foo_bar":1}|])
    end
  end

  context "given JSON" do
    it "deserializes a read" do
      Ktistec.database.exec(%Q|INSERT INTO options (key, value) VALUES ("#{key}", "{""foo_bar"":1}")|)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(FooBar?).new.tap do |r|
        rs.each do
          r << rs.read(FooBar?)
        end
      end
      expect(r).to eq([subject])
    end

    it "serializes a write" do
      Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, subject)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(String?).new.tap do |r|
        rs.each do
          r << rs.read(String?)
        end
      end
      expect(r).to eq([%q|{"foo_bar":1}|])
    end
  end

  context "given JSON" do
    it "deserializes a read" do
      Ktistec.database.exec(%Q|INSERT INTO options (key, value) VALUES ("#{key}", NULL)|)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(FooBar?).new.tap do |r|
        rs.each do
          r << rs.read(FooBar?)
        end
      end
      expect(r).to eq([nil])
    end

    it "serializes a write" do
      Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, nil)
      rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
      r = Array(String?).new.tap do |r|
        rs.each do
          r << rs.read(String?)
        end
      end
      expect(r).to eq([nil])
    end
  end

  context "strip" do
    it "strips the markup" do
      query = %q|SELECT strip("")|
      expect(Ktistec.database.scalar(query)).to eq("")
    end

    it "strips the markup" do
      query = %q|SELECT strip("text")|
      expect(Ktistec.database.scalar(query)).to eq("text")
    end

    it "strips the markup" do
      query = %q|SELECT strip('<body class="foobar"><div style="margin: inherit">line 1</div> <div>line <span>2</span></div></body>')|
      expect(Ktistec.database.scalar(query)).to eq("line 1 line 2")
    end
  end
end
