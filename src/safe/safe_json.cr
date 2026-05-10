require "json"

module Ktistec
  # A `String` wrapper marking JSON output safe to emit raw into the
  # body of an inert `<script type="application/json">` block.
  #
  struct SafeJSON
    def initialize(@value : String)
    end

    # Serializes `value` as JSON.
    #
    def self.from(value) : SafeJSON
      json = value.to_json
      json = json.gsub('<', "\\u003c")
      json = json.gsub('>', "\\u003e")
      json = json.gsub('&', "\\u0026")
      new(json)
    end

    # Asserts the input is already safe JSON.
    #
    def self.assert_safe(json : String) : SafeJSON
      new(json)
    end

    delegate :to_s, :empty?, :size, to: @value

    def ==(other : SafeJSON) : Bool
      @value == other.@value
    end

    def ==(other : String) : Bool
      @value == other
    end
  end
end
