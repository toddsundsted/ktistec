require "./crystal_scanner"

# Slang lexer.
#
# Consumes UTF-8 bytes of Slang source and emits a stream of tokens
# for the Slang parser. Indentation is handled here; the parser never
# inspects columns. Crystal expressions embedded in Slang are bounded
# by `CrystalScanner`.
#
# Each logical line begins with a line-opener token (Element, Output,
# Code, ...) followed by zero or more fragment tokens, terminated by
# Newline. Block structure is expressed by Indent and Dedent only.
#
module Slang
  enum TokenKind
    # structural
    Indent
    Dedent
    Newline
    EOF

    # line openers
    Element
    Output             # `=`
    OutputRaw          # `==`
    Code               # `-`
    TextBlock          # `|`
    TextBlockSpace     # `'`
    RawHtml            # `<...`
    CommentHidden      # `/`
    CommentVisible     # `/!`
    CommentConditional # `/[expr]`
    Doctype            # `doctype VALUE`

    # element-line fragments
    TagName
    ClassName
    IdName
    WsLeft  # `<` whitespace left
    WsRight # `>` whitespace right
    AttrName
    AttrValue
    SplatExpr   # Crystal expression following `*`
    InlineColon # literal `:` introducing inline element

    # output / code body fragments
    OutputExpr # Crystal expression following `=`/`==`
    CodeExpr   # Crystal expression following `-`

    # text fragments
    TextLiteral # verbatim text
    InterpExpr
  end

  # A single token.
  #
  # `value` carries the token's payload (the tag name, attribute name,
  # Crystal expression, literal text, ...). Empty for tokens whose
  # meaning is fully captured by `kind`.
  #
  # `line` and `column` point at the first byte of the token in the
  # source. Both are 1-based.
  #
  # `escape` is meaningful for text tokens (TextLiteral, InterpExpr)
  # and tells the codegen whether to apply HTML escaping.  The lexer
  # sets it from context. Default `true`.
  #
  struct Token
    getter kind : TokenKind
    getter value : String
    getter line : Int32
    getter column : Int32
    getter escape : Bool

    def initialize(@kind : TokenKind, @value : String = "",
                   @line : Int32 = 0, @column : Int32 = 0,
                   @escape : Bool = true)
    end
  end

  # Raised on lexical errors.
  #
  class LexError < Exception
    getter line : Int32
    getter column : Int32

    def initialize(message : String, @line : Int32, @column : Int32)
      super("#{message} at line #{@line}, column #{@column}")
    end
  end

  class Lexer
    @source : String
    @bytes : Bytes
    @pos : Int32
    @line : Int32
    @column : Int32
    @indent_stack : Array(Int32)
    @pending : Deque(Token)
    @done : Bool

    private LF     = 0x0A_u8
    private CR     = 0x0D_u8
    private SP     = 0x20_u8
    private TAB    = 0x09_u8
    private HASH   = '#'.ord.to_u8
    private DOT    = '.'.ord.to_u8
    private EQ     = '='.ord.to_u8
    private DASH   = '-'.ord.to_u8
    private PIPE   = '|'.ord.to_u8
    private QUOTE  = '\''.ord.to_u8
    private SLASH  = '/'.ord.to_u8
    private COLON  = ':'.ord.to_u8
    private LT     = '<'.ord.to_u8
    private GT     = '>'.ord.to_u8
    private STAR   = '*'.ord.to_u8
    private BANG   = '!'.ord.to_u8
    private LPAREN = '('.ord.to_u8
    private LBRACK = '['.ord.to_u8
    private LBRACE = '{'.ord.to_u8
    private RPAREN = ')'.ord.to_u8
    private RBRACK = ']'.ord.to_u8
    private RBRACE = '}'.ord.to_u8
    private BSLASH = '\\'.ord.to_u8

    # Crystal-expression terminators
    private OUTPUT_TERMINATORS = "\n"
    private CODE_TERMINATORS   = "\n"
    # `:` is intentionally NOT a value terminator: Crystal expressions
    # used as attribute values commonly include `::` as do symbol
    # literals. the inline-child marker `:` is recognized only after
    # the value scan stops at whitespace.
    private ATTR_VALUE_TERMINATORS = " \t<>\n"
    private SPLAT_TERMINATORS      = " \t<>\n"
    private INTERP_TERMINATOR      = "}"
    # used inside wrapped attribute lists. any depth-zero closer
    # ends the value; whitespace and newlines also end it (wrapper
    # body may span lines).
    private WRAPPED_VALUE_TERMINATORS = ") ] } \t\n"

    def initialize(source : String)
      @source = source
      @bytes = source.to_slice
      @pos = 0
      @line = 1
      @column = 1
      @indent_stack = [0]
      @pending = Deque(Token).new
      @done = false
    end

    # Returns the next token. Once `EOF` is returned, subsequent
    # calls also return `EOF`.
    #
    def next_token : Token
      while @pending.empty? && !@done
        fill_pending
      end
      if @pending.empty?
        Token.new(TokenKind::EOF, line: @line, column: @column)
      else
        @pending.shift
      end
    end

    private def fill_pending : Nil
      skip_blank_lines
      if eof?
        flush_dedents_to(0, line: @line, column: @column)
        @pending << Token.new(TokenKind::EOF, line: @line, column: @column)
        @done = true
        return
      end
      handle_indent
      scan_logical_line
    end

    # ----- Indentation -----

    private def skip_blank_lines : Nil
      while !eof?
        save_pos = @pos
        save_line = @line
        save_column = @column
        while !eof? && (peek == SP || peek == TAB)
          advance
        end
        if eof?
          return
        end
        case peek
        when LF, CR
          consume_newline
        else
          @pos = save_pos
          @line = save_line
          @column = save_column
          return
        end
      end
    end

    private def handle_indent : Nil
      indent = 0
      start_line = @line
      while !eof? && peek == SP
        indent += 1
        advance
      end
      if !eof? && peek == TAB
        raise LexError.new("tab in indentation (use spaces only)", @line, @column)
      end
      top = @indent_stack.last
      if indent > top
        @indent_stack << indent
        @pending << Token.new(TokenKind::Indent, line: start_line, column: 1)
      elsif indent < top
        flush_dedents_to(indent, line: start_line, column: 1)
        if @indent_stack.last != indent
          raise LexError.new("misaligned indentation", start_line, 1)
        end
      end
    end

    private def flush_dedents_to(target : Int32, *, line : Int32, column : Int32) : Nil
      while @indent_stack.last > target
        @indent_stack.pop
        @pending << Token.new(TokenKind::Dedent, line: line, column: column)
      end
    end

    # ----- Logical line dispatch -----

    private def scan_logical_line : Nil
      line = @line
      column = @column
      byte = peek
      case byte
      when EQ
        scan_output_line(line, column)
      when DASH
        scan_code_line(line, column)
      when PIPE
        scan_text_block(line, column, trailing_space: false)
      when QUOTE
        scan_text_block(line, column, trailing_space: true)
      when LT
        scan_raw_html_line(line, column)
      when SLASH
        scan_comment_line(line, column)
      when COLON
        # bare `:` at line start is a lex error.
        raise LexError.new("unexpected `:` at start of line", line, column)
      when DOT, HASH
        scan_implicit_div_line(line, column)
      else
        if name_byte?(byte)
          scan_named_element_or_doctype_line(line, column)
        else
          raise LexError.new("unexpected character `#{byte.unsafe_chr}`", line, column)
        end
      end
      consume_line_terminator
      @pending << Token.new(TokenKind::Newline, line: @line, column: @column)
    end

    # ----- Element lines -----

    private def scan_implicit_div_line(line : Int32, column : Int32) : Nil
      @pending << Token.new(TokenKind::Element, line: line, column: column)
      scan_element_tail(tag_name: nil)
    end

    private def scan_named_element_or_doctype_line(line : Int32, column : Int32) : Nil
      name_line = @line
      name_column = @column
      name_start = @pos
      consume_name_bytes
      name = String.new(@bytes[name_start, @pos - name_start])
      if !eof? && peek == COLON && rawstuff_keyword?(name)
        advance # the colon
        suffixed = name + ":"
        @pending << Token.new(TokenKind::Element, line: line, column: column)
        @pending << Token.new(TokenKind::TagName, value: suffixed,
          line: name_line, column: name_column)
        scan_rawstuff_body(opener_column: column)
        return
      end
      if name == "doctype"
        scan_doctype_line(line, column)
        return
      end
      @pending << Token.new(TokenKind::Element, line: line, column: column)
      @pending << Token.new(TokenKind::TagName, value: name,
        line: name_line, column: name_column)
      scan_element_tail(tag_name: name)
    end

    private def scan_element_tail(*, tag_name : String?) : Nil
      scan_shorthand_and_ws_controls
      scan_attributes_and_tail(tag_name: tag_name)
    end

    private def scan_shorthand_and_ws_controls : Nil
      loop do
        break if eof?
        case peek
        when DOT
          line = @line
          column = @column
          advance
          name = consume_name!
          @pending << Token.new(TokenKind::ClassName, value: name,
            line: line, column: column)
        when HASH
          line = @line
          column = @column
          advance
          name = consume_name!
          @pending << Token.new(TokenKind::IdName, value: name,
            line: line, column: column)
        when LT
          line = @line
          column = @column
          advance
          @pending << Token.new(TokenKind::WsLeft, line: line, column: column)
        when GT
          line = @line
          column = @column
          advance
          @pending << Token.new(TokenKind::WsRight, line: line, column: column)
        else
          break
        end
      end
    end

    private def scan_attributes_and_tail(*, tag_name : String?) : Nil
      if !eof? && wrapper_opener?(peek)
        scan_wrapped_attrs
      end

      # inline output (`=` / `==`) attaches to the element with no
      # leading whitespace required, mirroring the `:` inline-tag
      # form.

      if !eof? && peek == EQ
        scan_inline_output
        return
      end

      if !eof? && peek == COLON
        line = @line
        column = @column
        advance
        @pending << Token.new(TokenKind::InlineColon, line: line, column: column)
        skip_horizontal_ws
        return if at_line_end?
        scan_inline_child
        return
      end

      # beyond shorthand and wrapped attrs, attrs / inline-output /
      # inline-code / splat / trailing-text all require horizontal
      # whitespace as a separator. consume all of it.

      loop do
        break if at_line_end?
        if peek == SP || peek == TAB
          skip_horizontal_ws
          break if at_line_end?
        else
          break
        end
        byte = peek
        case byte
        when COLON
          line = @line
          column = @column
          advance
          @pending << Token.new(TokenKind::InlineColon, line: line, column: column)
          skip_horizontal_ws
          break if at_line_end?
          scan_inline_child
          return
        when EQ
          scan_inline_output
          return
        when DASH
          scan_inline_code
          return
        when STAR
          line = @line
          column = @column
          advance
          expr = scan_crystal_expression(SPLAT_TERMINATORS)
          if expr.empty?
            raise LexError.new("expected splat expression after `*`", line, column)
          end
          @pending << Token.new(TokenKind::SplatExpr, value: expr, line: line, column: column)
        else
          if name_byte?(byte) && attr_name_followed_by_eq?
            scan_unwrapped_attribute
          else
            scan_trailing_text(tag_name: tag_name)
            return
          end
        end
      end
    end

    private def scan_inline_child : Nil
      byte = peek
      case byte
      when EQ
        scan_inline_output
      when DASH
        scan_inline_code
      when DOT, HASH
        line = @line
        column = @column
        @pending << Token.new(TokenKind::Element, line: line, column: column)
        scan_element_tail(tag_name: nil)
      else
        if name_byte?(byte)
          line = @line
          column = @column
          name_start = @pos
          consume_name_bytes
          name = String.new(@bytes[name_start, @pos - name_start])
          @pending << Token.new(TokenKind::Element, line: line, column: column)
          @pending << Token.new(TokenKind::TagName, value: name,
            line: line, column: column)
          scan_element_tail(tag_name: name)
        else
          raise LexError.new("unexpected character `#{byte.unsafe_chr}` after `:`", @line, @column)
        end
      end
    end

    private def scan_inline_output : Nil
      line = @line
      column = @column
      escape = true
      advance # first `=`
      if !eof? && peek == EQ
        advance
        escape = false
      end
      kind = escape ? TokenKind::Output : TokenKind::OutputRaw
      @pending << Token.new(kind, line: line, column: column)
      scan_output_tail
    end

    private def scan_inline_code : Nil
      line = @line
      column = @column
      advance # `-`
      @pending << Token.new(TokenKind::Code, line: line, column: column)
      scan_code_tail
    end

    private def scan_unwrapped_attribute : Nil
      name_line = @line
      name_column = @column
      name_start = @pos
      consume_attr_name_bytes
      name = String.new(@bytes[name_start, @pos - name_start])
      @pending << Token.new(TokenKind::AttrName, value: name,
        line: name_line, column: name_column)
      return unless !eof? && peek == EQ
      advance
      value_line = @line
      value_column = @column
      expr = scan_crystal_expression(ATTR_VALUE_TERMINATORS)
      if expr.empty?
        raise LexError.new("expected attribute value after `=`", value_line, value_column)
      end
      @pending << Token.new(TokenKind::AttrValue, value: expr,
        line: value_line, column: value_column)
    end

    private def scan_wrapped_attrs : Nil
      opener = peek
      closer = paired_closer(opener)
      open_line = @line
      open_column = @column
      advance # consume opener

      loop do
        skip_inline_ws_and_newlines
        if eof?
          raise LexError.new("unterminated attribute wrapper (expected `#{closer.unsafe_chr}`)", open_line, open_column)
        end
        byte = peek
        if byte == closer
          advance
          return
        end
        if unexpected_closer?(byte, closer)
          raise LexError.new("mismatched attribute wrapper closer (expected `#{closer.unsafe_chr}`)", @line, @column)
        end
        if byte == STAR
          line = @line
          column = @column
          advance
          # include all wrapper closers in the terminator set so a
          # mismatched closer surfaces in the outer loop instead of
          # being silently consumed.
          expr = scan_crystal_expression(WRAPPED_VALUE_TERMINATORS)
          if expr.empty?
            raise LexError.new("expected splat expression after `*`", line, column)
          end
          @pending << Token.new(TokenKind::SplatExpr, value: expr,
            line: line, column: column)
          next
        end
        if !name_byte?(byte)
          raise LexError.new("unexpected character `#{byte.unsafe_chr}` in attribute list", @line, @column)
        end
        name_line = @line
        name_column = @column
        name_start = @pos
        consume_attr_name_bytes
        name = String.new(@bytes[name_start, @pos - name_start])
        @pending << Token.new(TokenKind::AttrName, value: name,
          line: name_line, column: name_column)
        next unless !eof? && peek == EQ
        advance
        value_line = @line
        value_column = @column
        expr = scan_crystal_expression(WRAPPED_VALUE_TERMINATORS)
        if expr.empty?
          raise LexError.new("expected attribute value after `=`", value_line, value_column)
        end
        @pending << Token.new(TokenKind::AttrValue, value: expr,
          line: value_line, column: value_column)
      end
    end

    # ----- Output / code lines -----

    private def scan_output_line(line : Int32, column : Int32) : Nil
      escape = true
      advance # first `=`
      if !eof? && peek == EQ
        advance
        escape = false
      end
      kind = escape ? TokenKind::Output : TokenKind::OutputRaw
      @pending << Token.new(kind, line: line, column: column)
      scan_output_tail
    end

    private def scan_output_tail : Nil
      while !eof? && (peek == LT || peek == GT)
        line = @line
        column = @column
        kind = peek == LT ? TokenKind::WsLeft : TokenKind::WsRight
        advance
        @pending << Token.new(kind, line: line, column: column)
      end
      skip_horizontal_ws
      expr_line = @line
      expr_column = @column
      expr = scan_crystal_expression(OUTPUT_TERMINATORS)
      if !expr.empty?
        @pending << Token.new(TokenKind::OutputExpr, value: expr,
          line: expr_line, column: expr_column)
      end
    end

    private def scan_code_line(line : Int32, column : Int32) : Nil
      advance # `-`
      @pending << Token.new(TokenKind::Code, line: line, column: column)
      scan_code_tail
    end

    private def scan_code_tail : Nil
      skip_horizontal_ws
      expr_line = @line
      expr_column = @column
      expr = scan_crystal_expression(CODE_TERMINATORS)
      if !expr.empty?
        @pending << Token.new(TokenKind::CodeExpr, value: expr,
          line: expr_line, column: expr_column)
      end
    end

    # ----- Text blocks -----

    private def scan_text_block(line : Int32, column : Int32, *, trailing_space : Bool) : Nil
      marker_column = column
      advance # `|` or `'`
      kind = trailing_space ? TokenKind::TextBlockSpace : TokenKind::TextBlock
      @pending << Token.new(kind, line: line, column: column)
      if !eof? && peek == SP
        advance
      end
      had_inline = !at_line_end?
      emit_text_with_interpolation(escape: false)
      consume_continuation_lines(opener_content_column: marker_column + 1, raw: false,
        first_emitted: had_inline)
    end

    # ----- Raw HTML line -----

    private def scan_raw_html_line(line : Int32, column : Int32) : Nil
      @pending << Token.new(TokenKind::RawHtml, line: line, column: column)
      emit_text_with_interpolation(escape: false)
    end

    # ----- Comments -----

    private def scan_comment_line(line : Int32, column : Int32) : Nil
      advance # `/`
      if !eof? && peek == BANG
        advance
        @pending << Token.new(TokenKind::CommentVisible, line: line, column: column)
        skip_horizontal_ws
        emit_text_with_interpolation(escape: true)
        return
      end
      if !eof? && peek == LBRACK
        advance # `[`
        bracket_line = @line
        bracket_column = @column
        cond_start = @pos
        while !eof? && peek != RBRACK && peek != LF && peek != CR
          advance
        end
        if eof? || peek != RBRACK
          raise LexError.new("unterminated conditional comment", line, column)
        end
        cond = String.new(@bytes[cond_start, @pos - cond_start])
        advance # `]`
        @pending << Token.new(TokenKind::CommentConditional, line: line, column: column)
        @pending << Token.new(TokenKind::TextLiteral, value: cond,
          line: bracket_line, column: bracket_column, escape: false)
        skip_horizontal_ws
        if !at_line_end?
          raise LexError.new("unexpected text after `]` in conditional comment", @line, @column)
        end
        return
      end
      # hidden comment. consume the rest of the line; emit the
      # literal so tooling can recover it.
      @pending << Token.new(TokenKind::CommentHidden, line: line, column: column)
      text_line = @line
      text_column = @column
      if !eof? && peek == SP
        advance
        text_line = @line
        text_column = @column
      end
      start = @pos
      while !eof? && peek != LF && peek != CR
        advance
      end
      text = String.new(@bytes[start, @pos - start])
      @pending << Token.new(TokenKind::TextLiteral, value: text,
        line: text_line, column: text_column, escape: false)
    end

    # ----- Doctype -----

    private def scan_doctype_line(line : Int32, column : Int32) : Nil
      @pending << Token.new(TokenKind::Doctype, line: line, column: column)
      skip_horizontal_ws
      text_line = @line
      text_column = @column
      start = @pos
      while !eof? && peek != LF && peek != CR
        advance
      end
      value = String.new(@bytes[start, @pos - start])
      @pending << Token.new(TokenKind::TextLiteral, value: value,
        line: text_line, column: text_column, escape: false)
    end

    # ----- Rawstuff bodies -----

    # called with the cursor just past the rawstuff opener's `:`.
    # the marker line itself terminates immediately at EOL; the
    # continuation lines are absorbed verbatim. leave the line
    # terminator for `consume_continuation_lines` to consume so that
    # both `|`/`'` and rawstuff entry contracts match (cursor at LF,
    # not past it).

    private def scan_rawstuff_body(*, opener_column : Int32) : Nil
      skip_horizontal_ws
      # `opener_column + 1` matches the text-block path: the
      # "content column" sits one to the right of the opener, so a
      # 2-space-indented body emits its content with no leading shift
      # (e.g., ` var x = 1;` becomes `var x = 1;` in the rendered
      # output).
      consume_continuation_lines(opener_content_column: opener_column + 1, raw: true)
    end

    # ----- Continuation-line consumer -----

    # used for both `|`/`'` text blocks and rawstuff bodies. the
    # content column for in-block detection is `opener_content_column
    # + 1` (so `opener_content_column` itself is the "block content
    # column" -- a line at column ≤ this column ends the block).
    #
    # blank lines inside the block are skipped silently; runs of
    # blanks collapse to a single `\n` separator (the leading `\n`
    # of the next non-blank content line). trailing blank lines
    # that precede a dedent or EOF emit nothing.
    #
    # in `raw: true` mode (rawstuff): each content line is emitted
    # as a single TextLiteral consisting of (optional) leading
    # newline + relative-indent spaces + the line's content.
    # interpolation is not honored.
    #
    # in `raw: false` mode (text block): each content line emits a
    # prefix TextLiteral (leading "\n" + relative-indent spaces),
    # then `emit_text_with_interpolation` for the line's content.
    # The prefix is omitted on the first emitted line when
    # `first_emitted` is false and relative_indent is zero.

    private def consume_continuation_lines(*, opener_content_column : Int32, raw : Bool, first_emitted : Bool = false) : Nil
      content_column = opener_content_column
      content_column_min = content_column + 1
      first = !first_emitted
      loop do
        # snapshot before consuming the line terminator so we can
        # rewind if the next physical line is dedented out of the
        # block.
        save_pos = @pos
        save_line = @line
        save_column = @column
        if at_line_end?
          if eof?
            return
          end
          consume_newline
        else
          return
        end
        # now at the start of a physical line. count leading spaces.
        col = 1
        while !eof? && peek == SP
          col += 1
          advance
        end
        if !eof? && peek == TAB
          raise LexError.new("tab in indentation (use spaces only)", @line, @column)
        end
        if eof?
          # trailing blank-then-EOF: nothing more to emit.
          return
        end
        if peek == LF || peek == CR
          # blank line inside the block. skip it -- runs of blank
          # lines collapse to a single separator, supplied by the
          # next non-blank content line's leading `\n`. trailing
          # blank lines (followed by dedent or EOF) emit nothing.
          next
        end
        if col <= content_column
          # dedented out of the block. rewind to before the newline
          # that introduced this physical line, so the outer state
          # machine sees this line at column 1 with no token already
          # consumed.
          @pos = save_pos
          @line = save_line
          @column = save_column
          return
        end
        relative_indent = col - content_column_min
        prefix = first ? " " * relative_indent : "\n" + " " * relative_indent
        if raw
          # in rawstuff mode, capture the rest of the line as a
          # single literal.
          start = @pos
          while !eof? && peek != LF && peek != CR
            advance
          end
          content = String.new(@bytes[start, @pos - start])
          @pending << Token.new(TokenKind::TextLiteral, value: prefix + content,
            line: save_line + 1, column: 1, escape: false)
        else
          unless prefix.empty?
            @pending << Token.new(TokenKind::TextLiteral, value: prefix,
              line: @line, column: 1, escape: false)
          end
          emit_text_with_interpolation(escape: false)
        end
        first = false
      end
    end

    # ----- Trailing text on element lines -----

    private def scan_trailing_text(*, tag_name : String?) : Nil
      # trailing text starting with `<` or under a script/style tag
      # is emitted unescaped. otherwise default to escaped.
      raw = (tag_name == "script" || tag_name == "style" || peek == LT)
      stopped = emit_text_with_interpolation(escape: !raw, transition_on_post_interp: !raw)
      return unless stopped
      case peek
      when EQ
        scan_inline_output
      when DASH
        scan_inline_code
      end
    end

    # ----- Text + interpolation scanning -----

    # scans bytes up to (but not including) the next LF/CR, emitting
    # TextLiteral and InterpExpr tokens. honors slang escapes.

    private def emit_text_with_interpolation(*, escape : Bool, transition_on_post_interp : Bool = false) : Bool
      buf = IO::Memory.new
      lit_line = @line
      lit_column = @column
      while !eof?
        byte = peek
        case byte
        when LF, CR
          break
        when BSLASH
          handled = false
          if @pos + 1 < @bytes.size
            nxt = @bytes[@pos + 1]
            if nxt == BSLASH || nxt == HASH || nxt == EQ || nxt == DASH
              advance # `\`
              advance # `\`, `#`, `=`, or `-`
              buf.write_byte(nxt)
              handled = true
            end
          end
          unless handled
            buf.write_byte(byte)
            advance
          end
        when HASH
          if @pos + 1 < @bytes.size && @bytes[@pos + 1] == LBRACE
            flush_text_literal(buf, lit_line, lit_column, false)
            interp_line = @line
            interp_column = @column
            advance # `#`
            advance # `{`
            expr_start = @pos
            end_pos = Slang::CrystalScanner.scan(@source, @pos, INTERP_TERMINATOR)
            if end_pos >= @bytes.size || @bytes[end_pos] != RBRACE
              raise LexError.new("unterminated interpolation `\#{...}`", interp_line, interp_column)
            end
            consume_to(end_pos)
            expr = String.new(@bytes[expr_start, @pos - expr_start])
            advance # `}`
            @pending << Token.new(TokenKind::InterpExpr, value: expr,
              line: interp_line, column: interp_column, escape: escape)
            if transition_on_post_interp && !eof? && (peek == EQ || peek == DASH)
              flush_text_literal(buf, lit_line, lit_column, false)
              return true
            end
            lit_line = @line
            lit_column = @column
          else
            buf.write_byte(byte)
            advance
          end
        else
          buf.write_byte(byte)
          advance
        end
      end
      flush_text_literal(buf, lit_line, lit_column, false)
      false
    end

    private def flush_text_literal(buf : IO::Memory, line : Int32, column : Int32, escape : Bool) : Nil
      return if buf.bytesize == 0
      s = buf.to_s
      buf.clear
      @pending << Token.new(TokenKind::TextLiteral, value: s,
        line: line, column: column, escape: escape)
    end

    # ----- Crystal expression scanning -----

    # returns the Crystal expression text from `@pos` up to the first
    # depth-zero terminator in `terminators`. advances `@pos`,
    # `@line`, `@column` past the consumed bytes (but not the
    # terminator).

    private def scan_crystal_expression(terminators : String) : String
      start = @pos
      end_pos = Slang::CrystalScanner.scan(@source, @pos, terminators)
      consume_to(end_pos)
      String.new(@bytes[start, @pos - start])
    end

    # ----- Cursor primitives -----

    private def consume_line_terminator : Nil
      return if eof?
      case peek
      when LF, CR
        consume_newline
      end
    end

    private def consume_newline : Nil
      if peek == CR
        @pos += 1
        if !eof? && peek == LF
          @pos += 1
          @line += 1
          @column = 1
        else
          raise LexError.new("expected `\\n` after `\\r`", @line, @column)
        end
      else
        advance
      end
    end

    private def skip_horizontal_ws : Nil
      while !eof? && (peek == SP || peek == TAB)
        advance
      end
    end

    private def skip_inline_ws_and_newlines : Nil
      loop do
        break if eof?
        case peek
        when SP, TAB
          advance
        when LF, CR
          consume_newline
        else
          break
        end
      end
    end

    private def at_line_end? : Bool
      eof? || peek == LF || peek == CR
    end

    private def consume_name_bytes : Nil
      while !eof? && name_byte?(peek)
        advance
      end
    end

    private def consume_attr_name_bytes : Nil
      while !eof?
        byte = peek
        if name_byte?(byte) || byte == COLON
          advance
        else
          break
        end
      end
    end

    private def consume_name! : String
      start = @pos
      consume_name_bytes
      if @pos == start
        raise LexError.new("expected name", @line, @column)
      end
      String.new(@bytes[start, @pos - start])
    end

    private def attr_name_followed_by_eq? : Bool
      i = @pos
      while i < @bytes.size && (name_byte?(@bytes[i]) || @bytes[i] == COLON)
        i += 1
      end
      return false if i == @pos
      i < @bytes.size && @bytes[i] == EQ
    end

    private def consume_to(target_pos : Int32) : Nil
      target = target_pos > @bytes.size ? @bytes.size : target_pos
      while @pos < target
        byte = @bytes[@pos]
        if byte == LF
          @line += 1
          @column = 1
        else
          @column += 1
        end
        @pos += 1
      end
    end

    private def advance : Nil
      return if eof?
      byte = @bytes[@pos]
      @pos += 1
      if byte == LF
        @line += 1
        @column = 1
      else
        @column += 1
      end
    end

    private def peek : UInt8
      @bytes[@pos]
    end

    private def eof? : Bool
      @pos >= @bytes.size
    end

    private def name_byte?(byte : UInt8) : Bool
      (byte >= 'a'.ord.to_u8 && byte <= 'z'.ord.to_u8) ||
        (byte >= 'A'.ord.to_u8 && byte <= 'Z'.ord.to_u8) ||
        (byte >= '0'.ord.to_u8 && byte <= '9'.ord.to_u8) ||
        byte == '_'.ord.to_u8 || byte == '-'.ord.to_u8
    end

    private def wrapper_opener?(byte : UInt8) : Bool
      byte == LPAREN || byte == LBRACK || byte == LBRACE
    end

    private def paired_closer(opener : UInt8) : UInt8
      case opener
      when LPAREN then RPAREN
      when LBRACK then RBRACK
      when LBRACE then RBRACE
      else
        raise "internal: not a wrapper opener: #{opener.unsafe_chr}"
      end
    end

    private def unexpected_closer?(byte : UInt8, expected : UInt8) : Bool
      return false if byte != RPAREN && byte != RBRACK && byte != RBRACE
      byte != expected
    end

    private def rawstuff_keyword?(name : String) : Bool
      name == "javascript" || name == "css" || name == "crystal"
    end
  end
end
