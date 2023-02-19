require "./lexer"

module Ktistec
  # A node in the parse tree.
  #
  class Node
    getter id : String
    getter lbp : Int32
    getter! token : Token

    # used in `Parser#current` to customize cloned nodes...

    protected setter id, lbp, token

    # Creates a node.
    #
    def initialize(@id, @lbp)
    end

    # Clones the node.
    #
    def clone
      self.dup
    end

    # Parses expression to the right.
    #
    def nud(parser : Parser) : self
      raise Parser::SyntaxError.new(parser, "unexpected token: #{id}")
    end

    # Parses expression to the right. Captures expression to the left.
    #
    def led(parser : Parser, left : Node) : self
      raise Parser::SyntaxError.new(parser, "unexpected token: #{id}")
    end

    # Parses statement.
    #
    def std(parser : Parser) : self
      raise Parser::SyntaxError.new(parser, "unexpected token: #{id}")
    end
  end

  # A literal.
  #
  class Literal < Node
    def nud(parser : Parser) : self
      self
    end
  end

  # A constant.
  #
  class Constant < Node
    def nud(parser : Parser) : self
      self
    end
  end

  # An identifier.
  #
  class Identifier < Node
    def nud(parser : Parser) : self
      self
    end
  end

  # An operator.
  #
  class Operator < Node
  end

  # A keyword.
  #
  # A keyword is a kind of identifier that has a syntactic role
  # specific to the language being implemented.
  #
  class Keyword < Identifier
  end

  # A prefix operator.
  #
  class PrefixOperator < Operator
    getter! right : Node

    # :inherit:
    def nud(parser : Parser) : self
      @right = parser.expression(lbp)
      raise Parser::SyntaxError.new(parser, "expecting expression") if right.token.eoi?
      self
    end
  end

  # An infix operator.
  #
  class InfixOperator < Operator
    getter! left : Node, right : Node

    # :inherit:
    def led(parser : Parser, @left : Node) : self
      @right = parser.expression(lbp)
      raise Parser::SyntaxError.new(parser, "expecting expression") if right.token.eoi?
      self
    end
  end

  # A function operator.
  #
  class FunctionOperator < Operator
    getter! left : Node, right : Array(Node)

    # :inherit:
    def led(parser : Parser, @left : Node) : self
      @right = right = [] of Node
      if parser.current.id != ")"
        loop do
          right << parser.expression(0)
          break if parser.current.id != ","
          parser.advance(",")
        end
      end
      parser.advance(")")
      raise Parser::SyntaxError.new(parser, "expecting identifier") unless @left.is_a?(Identifier)
      self
    end
  end

  # A rule definition.
  #
  class RuleDefinition < Node
    # A rule pattern.
    #
    class Pattern
      getter id
      getter! constant : Constant
      getter arguments = [] of Literal | Identifier
      getter options = {} of String => Literal | Identifier

      def initialize(@id : String)
      end

      # Parses a pattern in the rule definition.
      #
      def parse(parser : Parser) : self
        parser.advance(id)
        loop do
          case (node = parser.expression)
          when Constant
            raise Parser::SyntaxError.new(parser, "multiple constants are not permitted") if constant?
            @constant = node
          when Literal, Identifier, Operator
            @arguments << node
          end
          if parser.current.id == ":"
            parser.advance(":")
            key = arguments.pop
            value = parser.expression
            raise Parser::SyntaxError.new(parser, "key must be an identifier: #{key.id}") unless key.is_a?(Identifier)
            @options[key.id] = value
          end
          if parser.current.id == ","
            parser.advance(",")
            next
          else
            break
          end
        end
        raise Parser::SyntaxError.new(parser, "missing a constant") unless constant?
        self
      end
    end

    # rule definition implementation follows...

    getter! name : String
    getter trace : Bool = false
    getter patterns = [] of Pattern

    # :inherit:
    def std(parser : Parser) : self
      parser.advance(id)
      unless parser.current.token.string?
        raise Parser::SyntaxError.new(parser, "name must be a literal string")
      end
      @name = parser.current.token.as_s
      parser.advance
      loop do
        case parser.current.id
        when "trace"
          parser.advance("trace")
          @trace = true
        when "condition", "any", "none", "assert", "retract"
          pattern = Pattern.new(parser.current.id)
          patterns << pattern.parse(parser)
        else
          break
        end
      end
      parser.advance("end")
      self
    end

    # for the clone...

    protected setter patterns

    # Clones the node.
    #
    def clone
      super.tap do |clone|
        clone.patterns = self.patterns.dup
      end
    end
  end

  # Parses an input into a syntax tree.
  #
  class Parser
    @nodes = {} of String => Node

    private def register(id, lbp = 0, node = Node)
      @nodes[id] = node.new(id, lbp)
    end

    # Creates a parser for the given input.
    #
    def initialize(input : String)
      @lexer = Lexer.new(input)

      register("(end)")
      register("(literal)", 0, Literal)
      register("(constant)", 0, Constant)
      register("(identifier)", 0, Identifier)
      register("rule", 0, RuleDefinition)
      register("end", 0, Keyword)
      register("not", 500, PrefixOperator)
      register(".", 800, InfixOperator)
      register("(", 700, FunctionOperator)
      register(")")
      register(":")
      register(",")
    end

    @node : Node? = nil

    # Returns the current node.
    #
    def current : Node
      @node ||= begin
        token = @lexer.advance
        case token.type
        in Token::Type::EOI
          @nodes["(end)"].clone
        in Token::Type::String, Token::Type::Int, Token::Type::Float
          @nodes["(literal)"].clone.tap do |node|
            node.id = token.to_s
          end
        in Token::Type::Constant
          if @nodes.has_key?(token.as_s)
            @nodes[token.as_s].clone
          else
            @nodes["(constant)"].clone.tap do |node|
              node.id = token.as_s
            end
          end
        in Token::Type::Identifier
          if @nodes.has_key?(token.as_s)
            @nodes[token.as_s].clone
          else
            @nodes["(identifier)"].clone.tap do |node|
              node.id = token.as_s
            end
          end
        in Token::Type::Operator
          if @nodes.has_key?(token.as_s)
            @nodes[token.as_s].clone
          else
            raise SyntaxError.new(self, "invalid operator: #{token.as_s}")
          end
        in Token::Type::Error
          raise SyntaxError.new(self, token.as_s)
        end.tap do |node|
          node.token = token
        end
      end
    end

    # Advances the parser to the next node.
    #
    # If `id` is specified, raise an error if the id of the current
    # node does not match the specified id.
    #
    def advance(id : String? = nil)
      if id && @node.try(&.id) != id
        raise SyntaxError.new(self, "missing token: #{id}")
      end
      @node = nil
      self
    end

    # Parses next expression.
    #
    def expression(rbp = 0)
      node = current
      return node if node.token.eoi?
      advance
      left = node.nud(self)
      while rbp < current.lbp
        node = current
        advance
        left = node.led(self, left)
      end
      left
    end

    # Parses next statement.
    #
    def statement
      node = current
      return node if node.token.eoi?
      node.std(self)
    end

    # Returns all statements.
    #
    def statements
      Array(Node).new.tap do |statements|
        loop do
          statement = self.statement
          break if statement.token.eoi?
          statements << statement
        end
      end
    end

    # Raised to indicate a parse error.
    #
    class SyntaxError < Exception
      def initialize(@parser : Parser, message : String)
        super(message)
      end
    end
  end
end
