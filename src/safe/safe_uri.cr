require "../framework/util"

module Ktistec
  # A `String` wrapper marking a URL safe to emit raw into a URL
  # attribute slot (`href`, `src`, `action`, ...).
  #
  # Admits either an absolute URL with an allowed display scheme
  # (http, https, mailto, ...) or a path-only / query-only /
  # fragment-only relative reference.
  #
  struct SafeURI
    def initialize(@value : String)
    end

    # Validates and wraps the input.
    #
    # Returns `nil` if invalid.
    #
    def self.from?(string : String) : SafeURI?
      return if string.starts_with?("//")
      return unless ::Ktistec::Util.safe_url?(string)
      new(string)
    end

    # Validates and wraps the input.
    #
    # Raises `ArgumentError` if invalid.
    #
    def self.from(string : String) : SafeURI
      from?(string) || raise ArgumentError.new("not a safe URI: #{string.inspect}")
    end

    # Asserts the input is already a safe URI.
    #
    def self.assert_safe(string : String) : SafeURI
      new(string)
    end

    delegate :to_s, :empty?, :size, to: @value

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
