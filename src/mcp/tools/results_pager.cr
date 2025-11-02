require "../errors"
require "../../utils/json_rpc"

module MCP
  # Pagination for serving large result sets across multiple MCP tool
  # calls.
  #
  # Provides:
  # - TTL-based expiry
  # - LRU eviction when total entries exceed limit
  # - Opaque cursor-based pagination
  #
  # Usage:
  #     pager = ResultsPager(JSON::Any).new
  #     response = pager.store(large_results, page_size: 25)
  #     # => {page: [first 25 items], cursor: "eyJwb29sX2lkIjoiYWJjIiwicGFnZSI6Mn0="}
  #
  #     next_response = pager.fetch(response[:cursor])
  #     # => {page: [next 25 items], cursor: "..."}
  #
  class ResultsPager(T)
    Log = ::Log.for("mcp")

    TIME_TO_LIVE = 30.minutes

    MAX_TOTAL_ENTRIES = 10_000

    # accessor methods for testing (tests can override default values)

    protected def time_to_live : Time::Span
      TIME_TO_LIVE
    end

    protected def max_total_entries : Int32
      MAX_TOTAL_ENTRIES
    end

    private struct PagerEntry(T)
      property pager_id : String
      property results : Array(T)
      property page_size : Int32
      property time_to_live : Time::Span
      property total_pages : Int32
      property last_accessed : Time

      def initialize(@pager_id : String, @results : Array(T), @page_size : Int32, @time_to_live : Time::Span)
        @total_pages = (results.size.to_f / page_size).ceil.to_i
        @last_accessed = Time.utc
      end

      def touch
        @last_accessed = Time.utc
      end

      def expired? : Bool
        Time.utc - @last_accessed > @time_to_live
      end

      def page(page_num : Int32) : Array(T)?
        return nil if page_num < 1 || page_num > total_pages
        start_idx = (page_num - 1) * page_size
        end_idx = Math.min(start_idx + page_size, results.size)
        results[start_idx...end_idx]
      end
    end

    @pagers : Hash(String, PagerEntry(T))

    def initialize
      @pagers = {} of String => PagerEntry(T)
    end

    # Gets statistics about the result pager.
    #
    def stats : NamedTuple(pagers: Int32, total_entries: Int32)
      {pagers: @pagers.size, total_entries: total_entry_count}
    end

    # Returns total number of objects stored across all pagers.
    #
    private def total_entry_count : Int32
      @pagers.values.sum(&.results.size)
    end

    # Removes expired entries from the pager.
    #
    private def expire_stale_entries
      expired = @pagers.select { |_, entry| entry.expired? }
      expired.each do |pager_id, _|
        Log.debug { "Expiring pager entry: #{pager_id}" }
        @pagers.delete(pager_id)
      end
    end

    # Evicts least recently used entries until under limit.
    #
    private def evict_if_needed(exclude_pager_id : String? = nil)
      while total_entry_count > max_total_entries
        # find oldest accessed entry, excluding the one we just added
        oldest = @pagers
          .reject { |pager_id, _| pager_id == exclude_pager_id }
          .min_by? { |_, entry| entry.last_accessed }
        break unless oldest

        Log.warn { "Removing pager #{oldest[0]} (#{oldest[1].results.size} objects)" }
        @pagers.delete(oldest[0])
      end
    end

    # Stores results and returns first page with cursor.
    #
    # Arguments:
    # - results: Array of results to paginate
    # - page_size: Number of items per page
    #
    # Returns a named tuple:
    # - page: First page of results
    # - cursor: Cursor for fetching next page (or `nil` if only one page)
    #
    def store(results : Array(T), page_size : Int32) : NamedTuple(page: Array(T), cursor: String?)
      expire_stale_entries

      pager_id = Random::Secure.hex(16)
      entry = PagerEntry(T).new(pager_id, results, page_size, time_to_live)
      @pagers[pager_id] = entry

      evict_if_needed(exclude_pager_id: pager_id)

      page = entry.page(1) || [] of T
      cursor = entry.total_pages > 1 ? encode_cursor(pager_id, 2) : nil

      {page: page, cursor: cursor}
    end

    # Fetches next page using cursor.
    #
    # Arguments:
    # - cursor: Opaque cursor from previous `store`/`fetch` call
    #
    # Returns:
    # - page: Requested page of results
    # - cursor: Cursor for next page (or `nil` if last page)
    #
    # Raises:
    # - MCPError: If cursor is malformed, invalid, or expired
    #
    def fetch(cursor : String) : NamedTuple(page: Array(T), cursor: String?)
      pager_id, page_num = decode_cursor(cursor)

      entry = @pagers[pager_id]?
      raise MCPError.new("Invalid cursor", JSON::RPC::ErrorCodes::INVALID_PARAMS) unless entry

      if entry.expired?
        @pagers.delete(pager_id)
        raise MCPError.new("Expired cursor", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      entry.touch

      page = entry.page(page_num)
      raise MCPError.new("Invalid page number in cursor", JSON::RPC::ErrorCodes::INVALID_PARAMS) unless page

      next_cursor = page_num < entry.total_pages ? encode_cursor(pager_id, page_num + 1) : nil

      {page: page, cursor: next_cursor}
    end

    private def encode_cursor(pager_id : String, page_num : Int32) : String
      Base64.strict_encode("#{pager_id} #{page_num}")
    end

    private def decode_cursor(cursor : String) : {String, Int32}
      parts = Base64.decode_string(cursor).split(' ', 2)
      raise MCPError.new("Malformed cursor", JSON::RPC::ErrorCodes::INVALID_PARAMS) if parts.size != 2
      {parts[0].to_s, parts[1].to_i}
    rescue ex : Base64::Error | ArgumentError
      raise MCPError.new("Malformed cursor", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end
end
