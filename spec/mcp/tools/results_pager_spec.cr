require "../../../src/mcp/tools/results_pager"

require "../../spec_helper/base"

Spectator.describe MCP::ResultsPager do
  setup_spec

  subject { MCP::ResultsPager(String).new }

  it "stores and retrieves first page" do
    response = subject.store(["a", "b", "c", "d", "e"], 2)

    expect(response[:page]).to eq(["a", "b"])
    expect(response[:cursor]).not_to be_nil
  end

  it "retrieves subsequent pages" do
    response = subject.store(["a", "b", "c", "d", "e"], 2)
    expect(response[:cursor]).not_to be_nil

    page2 = subject.fetch(response[:cursor].not_nil!)
    expect(page2[:page]).to eq(["c", "d"])
    expect(page2[:cursor]).not_to be_nil

    page3 = subject.fetch(page2[:cursor].not_nil!)
    expect(page3[:page]).to eq(["e"])
    expect(page3[:cursor]).to be_nil
  end

  it "returns nil cursor on last page" do
    response = subject.store(["a", "b"], 5)

    expect(response[:page]).to eq(["a", "b"])
    expect(response[:cursor]).to be_nil
  end

  it "returns empty page for empty results" do
    response = subject.store([] of String, 10)

    expect(response[:page]).to be_empty
    expect(response[:cursor]).to be_nil
  end

  it "handles exact page size boundary" do
    response = subject.store(["a", "b", "c", "d"], 2)

    expect(response[:page]).to eq(["a", "b"])
    expect(response[:cursor]).not_to be_nil

    page2 = subject.fetch(response[:cursor].not_nil!)
    expect(page2[:page]).to eq(["c", "d"])
    expect(page2[:cursor]).to be_nil
  end

  it "raises error for invalid cursor format" do
    bad_cursor = "invalid!@#"
    expect { subject.fetch(bad_cursor) }.to raise_error(MCPError, /Malformed cursor/)
  end

  it "raises error for malformed cursor (not space-delimited)" do
    bad_cursor = Base64.strict_encode("notspacedelimited")
    expect { subject.fetch(bad_cursor) }.to raise_error(MCPError, /Malformed cursor/)
  end

  it "raises error for malformed cursor (non-numeric page number)" do
    bad_cursor = Base64.strict_encode("somepagerid notanumber")
    expect { subject.fetch(bad_cursor) }.to raise_error(MCPError, /Malformed cursor/)
  end

  it "raises error for non-existent pager_id" do
    cursor = Base64.strict_encode("nonexistent 2")
    expect { subject.fetch(cursor) }.to raise_error(MCPError, /Invalid cursor/)
  end

  it "raises error for invalid page number" do
    response = subject.store(["a", "b", "c", "d", "e"], 2)
    # manually craft a cursor with an out-of-range page number
    pager_id = Base64.decode_string(response[:cursor].not_nil!).split(' ')[0]
    bad_cursor = Base64.strict_encode("#{pager_id} 999")
    expect { subject.fetch(bad_cursor) }.to raise_error(MCPError, /Invalid page number/)
  end

  context "concurrent access" do
    let!(response1) { subject.store(["a", "b", "c", "d"], 2) }
    let!(response2) { subject.store(["w", "x", "y", "z"], 2) }

    it "maintains independent cursors" do
      stats = subject.stats
      expect(stats[:pagers]).to eq(2)

      page1_2 = subject.fetch(response1[:cursor].not_nil!)
      expect(page1_2[:page]).to eq(["c", "d"])

      page2_2 = subject.fetch(response2[:cursor].not_nil!)
      expect(page2_2[:page]).to eq(["y", "z"])
    end
  end

  describe "#stats" do
    it "provides statistics" do
      subject.store(["a", "b", "c"], 2)
      subject.store(["d", "e"], 2)
      stats = subject.stats
      expect(stats[:pagers]).to eq(2)
      expect(stats[:total_entries]).to eq(5)
    end
  end

  context "with short TIME_TO_LIVE for testing" do
    class ShortTTLPager < MCP::ResultsPager(String)
      protected def time_to_live : Time::Span
        0.05.seconds # 50ms
      end
    end

    subject { ShortTTLPager.new }

    it "expires old entries on store" do
      response1 = subject.store(["a", "b", "c"], 2)
      cursor1 = response1[:cursor].not_nil!

      stats = subject.stats
      expect(stats[:pagers]).to eq(1)

      page1 = subject.fetch(cursor1)
      expect(page1[:page]).to eq(["c"])

      sleep 0.10.seconds

      subject.store(["d", "e"], 2)

      stats = subject.stats
      expect(stats[:pagers]).to eq(1)

      expect { subject.fetch(cursor1) }.to raise_error(MCPError, /Invalid cursor/)
    end

    it "raises error when fetching expired cursor" do
      response = subject.store(["a", "b", "c"], 2)
      cursor = response[:cursor].not_nil!

      page2 = subject.fetch(cursor)
      expect(page2[:page]).to eq(["c"])

      sleep 0.10.seconds

      expect { subject.fetch(cursor) }.to raise_error(MCPError, /Expired cursor/)
    end
  end

  context "with low MAX_TOTAL_ENTRIES for testing" do
    class SmallMaxPager < MCP::ResultsPager(String)
      protected def max_total_entries : Int32
        10 # 10 total objects across all pagers
      end
    end

    subject { SmallMaxPager.new }

    it "evicts oldest when max_total_entries exceeded" do
      response1 = subject.store(["a1", "a2", "a3", "a4", "a5"], 2)
      sleep 0.01.seconds # ensure increasing timestamps
      response2 = subject.store(["b1", "b2", "b3", "b4", "b5"], 2)
      sleep 0.01.seconds
      response3 = subject.store(["c1", "c2", "c3", "c4", "c5"], 2)

      stats = subject.stats
      expect(stats[:pagers]).to eq(2)
      expect(stats[:total_entries]).to eq(10)

      cursor1 = response1[:cursor].not_nil!
      expect { subject.fetch(cursor1) }.to raise_error(MCPError, /Invalid cursor/)

      cursor2 = response2[:cursor].not_nil!
      page2 = subject.fetch(cursor2)
      expect(page2[:page]).to eq(["b3", "b4"])

      cursor3 = response3[:cursor].not_nil!
      page3 = subject.fetch(cursor3)
      expect(page3[:page]).to eq(["c3", "c4"])
    end

    it "never evicts the entry most recently added" do
      response1 = subject.store(["a1", "a2", "a3", "a4", "a5"], 2)
      sleep 0.01.seconds # ensure increasing timestamps
      response2 = subject.store(["b1", "b2", "b3", "b4", "b5"], 2)
      sleep 0.01.seconds
      response3 = subject.store(["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10", "c11", "c12"], 2)

      stats = subject.stats
      expect(stats[:pagers]).to eq(1)
      expect(stats[:total_entries]).to eq(12)

      cursor1 = response1[:cursor].not_nil!
      expect { subject.fetch(cursor1) }.to raise_error(MCPError, /Invalid cursor/)

      cursor2 = response2[:cursor].not_nil!
      expect { subject.fetch(cursor2) }.to raise_error(MCPError, /Invalid cursor/)

      cursor3 = response3[:cursor].not_nil!
      page3 = subject.fetch(cursor3)
      expect(page3[:page]).to eq(["c3", "c4"])
    end
  end
end
