require "../framework/util"

module Ktistec
  # A `String` wrapper marking a URL safe to emit raw into a URL
  # attribute slot (`href`, `src`, `action`, ...).
  #
  # `from?` and `from` validate input and admit only absolute URLs
  # with an allowlisted display scheme (http, https, mailto, tel,
  # ...).
  #
  struct SafeURI
    def initialize(@value : String)
    end

    # Validates and wraps the input.
    #
    # Admits an absolute URL with an allowlisted display scheme
    # (http, https, mailto, tel, ...). Rejects relative references.
    #
    # Returns `nil` if invalid.
    #
    # Use when the input is *expected to sometimes fail* and graceful
    # continuation is preferred.
    #
    def self.from?(string : String) : SafeURI?
      return if string.starts_with?("//")
      return unless ::Ktistec::Util.safe_url?(string)
      return unless ::Ktistec::Util.url_scheme(string)
      new(string)
    end

    # Validates and wraps the input.
    #
    # Same admission rules as `from?` (absolute URL, allowlisted
    # display scheme).
    #
    # Raises `ArgumentError` if invalid.
    #
    # Use when the input is *expected to always succeed* and a failure
    # indicates a bug worth surfacing.
    #
    def self.from(string : String) : SafeURI
      from?(string) || raise ArgumentError.new("not a safe URI: #{string.inspect}")
    end

    # Asserts the input is already a safe URI.
    #
    def self.assert_safe(string : String) : SafeURI
      new(string)
    end

    delegate :to_s, :to_json, :empty?, :size, to: @value

    # Returns `self` if the wrapped value has presence, otherwise `nil`.
    #
    def presence : SafeURI?
      @value.presence ? self : nil
    end

    def ==(other : SafeURI) : Bool
      @value == other.@value
    end

    def ==(other : String) : Bool
      @value == other
    end

    def =~(other : Regex)
      @value =~ other
    end
  end
end
