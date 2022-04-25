module Ktistec
  # A token.
  #
  struct Token
    # Supported token types.
    #
    enum Type
      EOI
      String
      Int
      Float
      Constant
      Identifier
      Operator
      Error
    end

    getter type, value

    delegate to_s, to: value

    # Creates a new token.
    #
    def initialize(@type : Type, @value : String | Int64 | Float64 | Nil = nil)
    end

    def eoi?
      Type::EOI == @type
    end

    def string?
      Type::String == @type
    end

    def as_s
      @value.as(String).to_s
    end

    def int?
      Type::Int == @type
    end

    def as_i
      @value.as(Int).to_i64
    end

    def float?
      Type::Float == @type
    end

    def as_f
      @value.as(Float).to_f64
    end

    def constant?
      Type::Constant == @type
    end

    def identifier?
      Type::Identifier == @type
    end

    def operator?
      Type::Operator == @type
    end

    def error?
      Type::Error == @type
    end
  end

  # Breaks an input into tokens.
  #
  class Lexer
    @size : Int32
    @index : Int32

    getter! token : Token

    # Creates a lexer for the given input.
    #
    def initialize(@input : String)
      @size = @input.size
      @index = 0
    end

    private def forward_while(&block)
      @index += 1
      while @index < @size
        c = @input[@index]
        break unless yield c
        @index += 1
      end
    end

    # Advances the lexer to the next token in the input.
    #
    # Returns the token.
    #
    def advance : Token
      while @index < @size
        c = @input[@index]
        case c
        # skip whitespace
        when .whitespace?
          @index += 1
          next
        # skip comments
        when '#'
          forward_while(&.in_set?("^\r\n"))
          next
        when '"'
          c = 0
          escaped = false
          builder = String::Builder.new
          @index += 1
          while @index < @size
            c = @input[@index]
            break if c == '"' && !escaped
            if c != '\\' || escaped
              escaped = false
              builder << c
            else
              escaped = true
            end
            @index += 1
          end
          @index += 1
          return @token =
            (c == '"') ?
              Token.new(Token::Type::String, builder.to_s) :
              Token.new(Token::Type::Error, "unterminated string")
        when '0'..'9'
          start = @index
          forward_while(&.in?('0'..'9'))
          float = false
          if @index < @size && @input[@index] == '.'
            forward_while(&.in?('0'..'9'))
            float = true
          end
          return @token =
            float ?
              Token.new(Token::Type::Float, @input[start..@index - 1].to_f64) :
              Token.new(Token::Type::Int, @input[start..@index - 1].to_i64)
        when 'A'..'Z'
          start = @index
          forward_while(&.in_set?("a-zA-Z0-9_"))
          return @token = Token.new(Token::Type::Constant, @input[start..@index - 1])
        when 'a'..'z'
          start = @index
          forward_while(&.in_set?("a-zA-Z0-9_"))
          return @token = Token.new(Token::Type::Identifier, @input[start..@index - 1])
        else
          @index += 1
          return @token = Token.new(Token::Type::Operator, @input[@index - 1].to_s)
        end
      end
      @token = Token.new(type: Token::Type::EOI)
    end
  end
end
