require "../../../src/framework/ext/sqlite3"

require "../../spec_helper/base"

Spectator.describe "SQLite3 extensions" do
  let(key) { random_string }

  it "deserializes a read" do
    r = nil
    c = 0
    Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, %Q<["one","two"]>)
    rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
    rs.each do
      r = rs.read(Array(String))
      c += 1
    end
    expect(r).to eq(["one", "two"])
    expect(c).to eq(1)
  end

  it "serializes a write" do
    r = nil
    c = 0
    Ktistec.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, ["one", "two"])
    rs = Ktistec.database.query("SELECT value FROM options WHERE key = ?", key)
    rs.each do
      r = rs.read(String)
      c += 1
    end
    expect(r).to eq(%Q<["one","two"]>)
    expect(c).to eq(1)
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
