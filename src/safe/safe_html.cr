require "html"

require "../framework/util"

module Ktistec
  # A `String` wrapper marking HTML markup safe to emit raw into HTML
  # data slots (text content, between tags). Not admissible into
  # attribute slots — `SafeAttrValue` covers that.
  #
  struct SafeHTML
    def initialize(@value : String)
    end

    # HTML-escapes the input.
    #
    def self.escape(string : String?) : SafeHTML
      return new("") if string.nil?
      new(::HTML.escape(string))
    end

    # Sanitizes the input.
    #
    def self.sanitize(content : String?) : SafeHTML
      ::Ktistec::Util.sanitize(content)
    end

    # Asserts the input is already safe.
    #
    def self.assert_safe(string : String) : SafeHTML
      new(string)
    end

    delegate :to_s, :empty?, :size, :includes?, to: @value

    # Returns `self` if the wrapped value has presence, otherwise `nil`.
    #
    def presence : SafeHTML?
      @value.presence ? self : nil
    end

    def ==(other : SafeHTML) : Bool
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
