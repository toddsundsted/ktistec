require "../../spec_helper"

Spectator.describe "SQLite3 extensions" do
  let(key) { random_string }

  it "deserializes a read" do
    r = nil
    c = 0
    Balloon.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, %Q<["one","two"]>)
    rs = Balloon.database.query("SELECT value FROM options WHERE key = ?", key)
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
    Balloon.database.exec("INSERT INTO options (key, value) VALUES (?, ?)", key, ["one", "two"])
    rs = Balloon.database.query("SELECT value FROM options WHERE key = ?", key)
    rs.each do
      r = rs.read(String)
      c += 1
    end
    expect(r).to eq(%Q<["one","two"]>)
    expect(c).to eq(1)
  end
end
