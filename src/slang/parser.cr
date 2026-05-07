require "./lexer"
require "./ast"

# Slang parser.
#
# Crystal expressions inside templates are passed through verbatim
# from the lexer -- the parser does not validate them.
#
module Slang
  class ParseError < Exception
    getter line : Int32
    getter column : Int32

    def initialize(message : String, @line : Int32, @column : Int32)
      super("#{message} at line #{@line}, column #{@column}")
    end
  end

  class Parser
    @lexer : Lexer
    @current : Token

    # Parses `source` and returns the resulting document.
    #
    def self.parse(source : String) : AST::Document
      new(source).parse_document
    end

    def initialize(source : String)
      @lexer = Lexer.new(source)
      @current = @lexer.next_token
    end

    def parse_document : AST::Document
      doc = AST::Document.new(AST::SourceLoc.new(1, 1))
      doc.nodes.concat(parse_block)
      expect(TokenKind::EOF)
      doc
    end

    # ----- Block-level dispatch -----

    private def parse_block : Array(AST::Node)
      nodes = [] of AST::Node
      loop do
        case @current.kind
        when TokenKind::EOF, TokenKind::Dedent
          return nodes
        when TokenKind::Element
          nodes << parse_element_line
        when TokenKind::Output, TokenKind::OutputRaw
          nodes << parse_output_line
        when TokenKind::Code
          code = parse_code_line
          if (branch = code.branch)
            host = find_branchable_host(nodes)
            host_kind = host.try(&.branchable)
            if host && host_kind && branchable_allows?(host_kind, branch)
              host.branches << code
              next
            end
            raise ParseError.new(
              "branch `#{first_keyword(code.expr)}` has no matching preceding branchable",
              code.loc.line, code.loc.column,
            )
          end
          nodes << code
        when TokenKind::TextBlock, TokenKind::TextBlockSpace
          nodes << parse_text_block_line
        when TokenKind::RawHtml
          nodes << parse_raw_html_line
        when TokenKind::CommentHidden
          nodes << parse_hidden_comment_line
        when TokenKind::CommentVisible
          nodes << parse_visible_comment_line
        when TokenKind::Doctype
          nodes << parse_doctype_line
        else
          raise ParseError.new(
            "unexpected #{@current.kind} at start of line",
            @current.line, @current.column,
          )
        end
      end
    end

    # ----- Element line -----

    # `<script>` content types that the browser does not execute.
    #
    # A `<script>` with one of these `type` values may have Slang
    # children; any other `<script>` must be bodyless. `<style>` is
    # always bodyless.
    #
    INERT_SCRIPT_TYPES = %w[application/json application/ld+json text/template text/plain]

    private def parse_element_line : AST::Node
      open = consume # Element
      loc = AST::SourceLoc.new(open.line, open.column)
      tag = at?(TokenKind::TagName) ? consume.value : "div"
      if (flavor = rawstuff_flavor(tag))
        return parse_rawstuff_body(flavor, loc)
      end
      el = AST::Element.new(tag, loc)
      innermost = parse_element_fragments(el)
      expect(TokenKind::Newline)
      if at?(TokenKind::Indent)
        consume
        innermost.children.concat(parse_block)
        expect(TokenKind::Dedent)
      end
      validate_element_canonical_form!(el)
      el
    end

    # Validates that the element conforms to a canonical form.
    #
    #   <script src="...">   (bodyless)         — allowed (loads external JS)
    #   <script type="...">  (inert + body)     — allowed (chart data / JSON-LD / template scaffold)
    #   <script>             (other forms)      — banned (use `javascript:` or `script src="..."`)
    #   <style>                                 — banned (use `css:` or `<link rel="...">`)
    #   void elements (br, img, hr, ...)        — banned
    #   everything else                         — accepted
    #
    private def validate_element_canonical_form!(el : AST::Element) : Nil
      tag = el.tag.downcase
      case tag
      when "style"
        raise ParseError.new(
          "`<style>` elements are banned; use a `css:` block, or `<link rel=\"stylesheet\">` to load an external stylesheet",
          el.loc.line, el.loc.column,
        )
      when "script"
        if el.children.empty?
          return if script_has_named_src?(el)
          raise ParseError.new(
            "bodyless `<script>` requires a named `src=` attribute; use `script src=\"...\"` to load external JavaScript, or a `javascript:` block",
            el.loc.line, el.loc.column,
          )
        end
        return if script_inert?(el)
        raise ParseError.new(
          "`<script>` with executable type cannot have Slang children or trailing text; use a `javascript:` block, or set `type=` to an inert content type (#{INERT_SCRIPT_TYPES.join(", ")})",
          el.loc.line, el.loc.column,
        )
      else
        if AST::VOID_ELEMENTS.includes?(tag) && !el.children.empty?
          raise ParseError.new(
            "void element `<#{tag}>` cannot have Slang children or trailing text; void elements (`#{AST::VOID_ELEMENTS.join("`, `")}`) are bodyless by definition",
            el.loc.line, el.loc.column,
          )
        end
      end
    end

    private def script_has_named_src?(el : AST::Element) : Bool
      el.attrs.any? { |a| a.name.downcase == "src" }
    end

    private def script_inert?(el : AST::Element) : Bool
      type_attr = el.attrs.find { |a| a.name.downcase == "type" }
      return false unless type_attr
      value = simple_string_literal(type_attr.value)
      return false unless value
      INERT_SCRIPT_TYPES.includes?(value.downcase)
    end

    private def simple_string_literal(expr : String) : String?
      return if expr.size < 2
      return unless expr.starts_with?('"') && expr.ends_with?('"')
      inner = expr[1..-2]
      return if inner.includes?('\\') || inner.includes?('"')
      inner
    end

    # builds the bare `Element` from an `Element` opener token and
    # optional `TagName`.

    private def build_element : AST::Element
      open = consume # Element
      loc = AST::SourceLoc.new(open.line, open.column)
      tag = at?(TokenKind::TagName) ? consume.value : "div"
      AST::Element.new(tag, loc)
    end

    private def rawstuff_flavor(tag : String) : AST::RawstuffFlavor?
      case tag
      when "javascript:" then AST::RawstuffFlavor::JavaScript
      when "css:"        then AST::RawstuffFlavor::CSS
      when "crystal:"    then AST::RawstuffFlavor::Crystal
      end
    end

    private def parse_rawstuff_body(flavor : AST::RawstuffFlavor, loc : AST::SourceLoc) : AST::Rawstuff
      raw = AST::Rawstuff.new(flavor, loc)
      while at?(TokenKind::TextLiteral) || at?(TokenKind::InterpExpr)
        raw.parts << consume_text_part
      end
      expect(TokenKind::Newline)
      raw
    end

    # consumes the fragment-token sequence after an `Element` opener
    # (and optional `TagName`). stops at `Newline`. returns the
    # innermost node of the line; for inline output/code or for an
    # inline-element chain, the innermost node in that chain.

    private def parse_element_fragments(el : AST::Element) : AST::IndentHost
      loop do
        case @current.kind
        when TokenKind::ClassName
          el.classes << consume.value
        when TokenKind::IdName
          tok = consume
          if el.id
            raise ParseError.new(
              "element has multiple `#id` shorthands",
              tok.line, tok.column,
            )
          end
          el.id = tok.value
        when TokenKind::WsLeft
          consume
          el.ws_left = true
        when TokenKind::WsRight
          consume
          el.ws_right = true
        when TokenKind::AttrName
          parse_attribute(el)
        when TokenKind::SplatExpr
          tok = consume
          el.splats << AST::Splat.new(
            tok.value,
            AST::SourceLoc.new(tok.line, tok.column),
          )
        when TokenKind::InlineColon
          consume
          return parse_inline_child(el)
        when TokenKind::Output, TokenKind::OutputRaw
          output = parse_inline_output
          el.children << output
          return output
        when TokenKind::Code
          code = parse_inline_code
          el.children << code
          return code
        when TokenKind::TextLiteral, TokenKind::InterpExpr
          el.children << parse_trailing_text
        when TokenKind::Newline
          return el
        else
          raise ParseError.new(
            "unexpected #{@current.kind} in element line",
            @current.line, @current.column,
          )
        end
      end
    end

    # after an `InlineColon`, parses the next inline construct and
    # appends it to `children`. returns the innermost node of the
    # resulting chain, for indent-block attachment by the outer
    # element line.

    private def parse_inline_child(el : AST::Element) : AST::IndentHost
      case @current.kind
      when TokenKind::Element
        inner = build_element
        innermost = parse_element_fragments(inner)
        el.children << inner
        innermost
      when TokenKind::Output, TokenKind::OutputRaw
        output = parse_inline_output
        el.children << output
        output
      when TokenKind::Code
        code = parse_inline_code
        el.children << code
        code
      else
        raise ParseError.new(
          "expected element, output, or code after `:`",
          @current.line, @current.column,
        )
      end
    end

    private def parse_attribute(el : AST::Element) : Nil
      name_tok = consume # AttrName
      unless at?(TokenKind::AttrValue)
        raise ParseError.new(
          "attribute `#{name_tok.value}` is missing a value",
          name_tok.line, name_tok.column,
        )
      end
      value_tok = consume
      el.attrs << AST::Attribute.new(
        name_tok.value,
        value_tok.value,
        AST::SourceLoc.new(value_tok.line, value_tok.column),
      )
    end

    private def parse_trailing_text : AST::Text
      first = @current
      text = AST::Text.new(AST::SourceLoc.new(first.line, first.column))
      while at?(TokenKind::TextLiteral) || at?(TokenKind::InterpExpr)
        text.parts << consume_text_part
      end
      text
    end

    # consumes a `TextLiteral` or `InterpExpr` and returns the
    # equivalent `TextPart`.

    private def consume_text_part : AST::TextPart
      tok = consume
      loc = AST::SourceLoc.new(tok.line, tok.column)
      case tok.kind
      when TokenKind::TextLiteral
        AST::Literal.new(tok.value, tok.escape, loc)
      when TokenKind::InterpExpr
        AST::Interp.new(tok.value, tok.escape, loc)
      else
        raise ParseError.new(
          "expected text literal or interpolation, got #{tok.kind}",
          tok.line, tok.column,
        )
      end
    end

    # ----- Inline output / code (used as element children) -----

    # parses inline output: Output|OutputRaw + WsLeft/WsRight* +
    # OutputExpr?. does not consume `Newline`; the outer line takes
    # care of that.

    private def parse_inline_output : AST::Output
      open = consume # Output | OutputRaw
      escape = open.kind == TokenKind::Output
      ws_left = false
      ws_right = false
      loop do
        case @current.kind
        when TokenKind::WsLeft
          consume
          ws_left = true
        when TokenKind::WsRight
          consume
          ws_right = true
        else
          break
        end
      end
      if at?(TokenKind::OutputExpr)
        expr_tok = consume
        expr = expr_tok.value
        loc = AST::SourceLoc.new(expr_tok.line, expr_tok.column)
      else
        expr = ""
        loc = AST::SourceLoc.new(open.line, open.column)
      end
      output = AST::Output.new(expr, escape, loc)
      output.ws_left = ws_left
      output.ws_right = ws_right
      output
    end

    # parses inline code: Code + CodeExpr?. does not consume
    # `Newline`. branchable / branch tagging is set from the leading
    # keyword of `expr`.

    private def parse_inline_code : AST::Code
      open = consume # Code
      if at?(TokenKind::CodeExpr)
        expr_tok = consume
        expr = expr_tok.value
        loc = AST::SourceLoc.new(expr_tok.line, expr_tok.column)
      else
        expr = ""
        loc = AST::SourceLoc.new(open.line, open.column)
      end
      branchable = detect_branchable(expr)
      branch = branchable ? nil : detect_branch(expr)
      AST::Code.new(expr, branchable, branch, loc)
    end

    # ----- Branchable / branch detection -----

    private def detect_branchable(expr : String) : AST::BranchableKind?
      case first_keyword(expr)
      when "if"    then AST::BranchableKind::If
      when "case"  then AST::BranchableKind::Case
      when "begin" then AST::BranchableKind::Begin
      end
    end

    private def detect_branch(expr : String) : AST::BranchKind?
      case first_keyword(expr)
      when "else"   then AST::BranchKind::Else
      when "elsif"  then AST::BranchKind::Elsif
      when "when"   then AST::BranchKind::When
      when "in"     then AST::BranchKind::In
      when "rescue" then AST::BranchKind::Rescue
      when "ensure" then AST::BranchKind::Ensure
      end
    end

    # returns the leading run of name characters from `expr` -- the
    # candidate keyword. anything past the first non-`[A-Za-z0-9_]`
    # byte is the branch/branchable's argument or terminator.

    private def first_keyword(expr : String) : String
      expr.chars.take_while { |c| c.alphanumeric? || c == '_' }.join
    end

    private def branchable_allows?(branchable : AST::BranchableKind, branch : AST::BranchKind) : Bool
      case branchable
      in AST::BranchableKind::If
        branch.elsif? || branch.else?
      in AST::BranchableKind::Case
        branch.when? || branch.in? || branch.else?
      in AST::BranchableKind::Begin
        branch.rescue? || branch.ensure? || branch.else?
      end
    end

    private def find_branchable_host(nodes : Array(AST::Node)) : AST::Code?
      nodes.reverse_each do |n|
        if n.is_a?(AST::Code) && n.branchable
          return n
        end
      end
      nil
    end

    # ----- Top-level output / code / text-block / raw-HTML lines -----

    private def parse_output_line : AST::Output
      output = parse_inline_output
      expect(TokenKind::Newline)
      if at?(TokenKind::Indent)
        consume
        output.children.concat(parse_block)
        expect(TokenKind::Dedent)
      end
      output
    end

    private def parse_code_line : AST::Code
      code = parse_inline_code
      expect(TokenKind::Newline)
      if at?(TokenKind::Indent)
        consume
        code.children.concat(parse_block)
        expect(TokenKind::Dedent)
      end
      code
    end

    private def parse_text_block_line : AST::TextBlock
      open = consume # TextBlock | TextBlockSpace
      loc = AST::SourceLoc.new(open.line, open.column)
      kind = open.kind == TokenKind::TextBlock ? AST::TextBlockKind::Pipe : AST::TextBlockKind::Quote
      block = AST::TextBlock.new(kind, loc)
      while at?(TokenKind::TextLiteral) || at?(TokenKind::InterpExpr)
        block.parts << consume_text_part
      end
      expect(TokenKind::Newline)
      block
    end

    private def parse_raw_html_line : AST::RawHtml
      open = consume # RawHtml
      loc = AST::SourceLoc.new(open.line, open.column)
      raw = AST::RawHtml.new(loc)
      while at?(TokenKind::TextLiteral) || at?(TokenKind::InterpExpr)
        raw.parts << consume_text_part
      end
      expect(TokenKind::Newline)
      raw
    end

    private def parse_hidden_comment_line : AST::HiddenComment
      open = consume # CommentHidden
      loc = AST::SourceLoc.new(open.line, open.column)
      # discard the body text; hidden comments emit nothing at runtime.
      while at?(TokenKind::TextLiteral) || at?(TokenKind::InterpExpr)
        consume
      end
      expect(TokenKind::Newline)
      node = AST::HiddenComment.new(loc)
      if at?(TokenKind::Indent)
        consume
        node.children.concat(parse_block)
        expect(TokenKind::Dedent)
      end
      node
    end

    private def parse_visible_comment_line : AST::VisibleComment
      open = consume # CommentVisible
      loc = AST::SourceLoc.new(open.line, open.column)
      node = AST::VisibleComment.new(loc)
      while at?(TokenKind::TextLiteral) || at?(TokenKind::InterpExpr)
        node.parts << consume_text_part
      end
      expect(TokenKind::Newline)
      if at?(TokenKind::Indent)
        consume
        node.children.concat(parse_block)
        expect(TokenKind::Dedent)
      end
      node
    end

    private def parse_doctype_line : AST::Doctype
      open = consume # Doctype
      loc = AST::SourceLoc.new(open.line, open.column)
      value = at?(TokenKind::TextLiteral) ? consume.value : ""
      expect(TokenKind::Newline)
      AST::Doctype.new(value, loc)
    end

    # ----- Token primitives -----

    private def at?(kind : TokenKind) : Bool
      @current.kind == kind
    end

    private def consume : Token
      tok = @current
      @current = @lexer.next_token
      tok
    end

    private def expect(kind : TokenKind) : Token
      unless @current.kind == kind
        raise ParseError.new(
          "expected #{kind}, got #{@current.kind}",
          @current.line, @current.column,
        )
      end
      consume
    end
  end
end
