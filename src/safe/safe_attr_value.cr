require "html"

module Ktistec
  # A `String` wrapper marking a value safe to emit raw inside a
  # double-quoted HTML attribute (`attr="..."`), other than URL or
  # event-handler slots. Not interchangeable with `SafeHTML`: HTML
  # markup like `<em>x</em>` is `SafeHTML` but is not safe inside an
  # attribute value.
  #
  struct SafeAttrValue
    protected def initialize(@value : String)
    end

    # Attribute-encodes the input.
    #
    def self.escape(string : String?) : SafeAttrValue
      return new("") if string.nil?
      new(::HTML.escape(string))
    end

    # Attribute-encodes the input.
    #
    def self.escape(value : Int) : SafeAttrValue
      new(value.to_s)
    end

    # Asserts the input is already safe inside an HTML attribute.
    #
    def self.assert_safe(string : String) : SafeAttrValue
      new(string)
    end

    delegate :to_s, :to_json, :empty?, :size, :includes?, to: @value

    # Returns `self` if the wrapped value has presence, otherwise `nil`.
    #
    def presence : SafeAttrValue?
      @value.presence ? self : nil
    end

    def ==(other : SafeAttrValue) : Bool
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
