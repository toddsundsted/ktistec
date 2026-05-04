require "html"
require "./ast"
require "./runtime"

# Slang codegen.
#
# Walks an `AST::Document` and emits Crystal source that, at runtime,
# writes the rendered HTML to a buffer named `buffer_name`. The buffer
# must be an `IO`.
#
module Slang
  class CodeGen
    @output : String::Builder
    @literal : String::Builder
    @buffer_name : String
    @filename : String?
    @sub_count : Int32

    # Emits Crystal source for `document`. `filename` is used for
    # source-attribution directives; pass `nil` or `""` to disable.
    # `buffer_name` is the local variable the generated code writes
    # HTML to.
    #
    def self.generate(document : AST::Document,
                      filename : String?,
                      buffer_name : String) : String
      new(filename, buffer_name).generate(document)
    end

    def initialize(filename : String?, @buffer_name : String)
      @output = String::Builder.new
      @literal = String::Builder.new
      @filename = filename.try { |f| f.empty? ? nil : f }
      @sub_count = 0
    end

    def generate(document : AST::Document) : String
      if (filename = @filename)
        @output << "#<loc:push>#<loc:"
        @output << filename.dump
        @output << ",1,1>\n"
      end
      document.nodes.each { |node| emit_node(node) }
      flush_literal
      if @filename
        @output << "#<loc:pop>\n"
      end
      @output.to_s
    end

    # ----- literal accumulator -----

    # Appends a literal byte sequence to the accumulator. No escaping
    # is applied here -- caller is responsible for HTML-escaping
    # anything untrusted before calling this.
    #
    private def emit_literal(str : String) : Nil
      @literal << str
    end

    # Flushes the accumulator as one `buffer << "..."` line. No-op if
    # the accumulator is empty. Avoid calling `to_s` on an empty
    # builder -- `String::Builder#to_s` is destructive and the builder
    # cannot be reused once consumed.
    #
    private def flush_literal : Nil
      return if @literal.bytesize == 0
      @output << @buffer_name << " << " << @literal.to_s.dump << '\n'
      @literal = String::Builder.new
    end

    # Emits a `#<loc:"FILE",L,C>` directive on its own line. No-op if
    # filename is nil/empty.
    #
    private def emit_loc(loc : AST::SourceLoc) : Nil
      return unless (filename = @filename)
      @output << "#<loc:"
      @output << filename.dump
      @output << ',' << loc.line << ',' << loc.column << ">\n"
    end

    # Allocate a fresh deterministic sub-buffer name. Counter resets
    # every `generate` call.
    #
    private def fresh_sub_buffer : String
      @sub_count += 1
      "__sub_#{@sub_count}__"
    end

    # ----- node dispatch -----

    private def emit_node(node : AST::Node) : Nil
      case node
      when AST::Element        then emit_element(node)
      when AST::Output         then emit_output(node)
      when AST::Code           then emit_code(node)
      when AST::Text           then emit_text_node(node)
      when AST::TextBlock      then emit_text_block(node)
      when AST::RawHtml        then emit_raw_html(node)
      when AST::HiddenComment  then emit_hidden_comment(node)
      when AST::VisibleComment then emit_visible_comment(node)
      when AST::Doctype        then emit_doctype(node)
      when AST::Rawstuff       then emit_rawstuff(node)
      else
        # Document is handled by `generate`; reaching here means the
        # parser produced an unexpected node type for `emit_node` to
        # dispatch on -- a parser-codegen contract violation.
        raise "Slang::CodeGen: unexpected node #{node.class}"
      end
    end

    private def emit_hidden_comment(node : AST::HiddenComment) : Nil
      # intentionally empty
    end

    SELF_CLOSING_TAGS = {
      "area", "base", "br", "col", "embed", "hr", "img", "input",
      "keygen", "link", "menuitem", "meta", "param", "source",
      "track", "wbr",
    }

    # ----- Element -----

    private def emit_element(node : AST::Element) : Nil
      emit_literal(" ") if node.ws_left

      # evaluate splats into local temporaries so we can read them
      # multiple times (once for class merging, once for non-class
      # iteration) without re-evaluating user expressions.

      splat_temps = [] of String
      node.splats.each do |splat|
        @sub_count += 1
        temp = "__slang_splat_#{@sub_count}__"
        flush_literal
        emit_loc(splat.loc)
        @output << temp << " = (" << splat.expr << ")\n"
        splat_temps << temp
      end

      emit_literal("<")
      emit_literal(node.tag)

      # `id` is hoisted to the front and `class` follows immediately
      # after, regardless of source order.

      if (id = node.id)
        emit_literal(" id=\"")
        emit_literal(::HTML.escape(id))
        emit_literal("\"")
      else
        if (id_attr = node.attrs.find { |a| a.name == "id" })
          emit_attr(id_attr)
        end
      end

      class_emitted = false
      any_class_source = !node.classes.empty? ||
                         node.attrs.any? { |a| a.name == "class" } ||
                         !splat_temps.empty?

      if !node.classes.empty? || node.attrs.any? { |a| a.name == "class" }
        emit_class_merge(node, splat_temps)
        class_emitted = true
      end

      # other attributes in source order, skipping id and class
      # (handled above).

      node.attrs.each do |attr|
        next if attr.name == "id"
        next if attr.name == "class"
        emit_attr(attr)
      end

      # splat-only class case: no shorthand and no class= attr, but
      # a splat may yield a `class` key. emit the merge here, before
      # the splat-each iteration that follows.

      if any_class_source && !class_emitted
        emit_class_merge(node, splat_temps)
      end

      splat_temps.each do |temp|
        flush_literal
        @output << "::Slang::Runtime.emit_splat_attrs(" << @buffer_name
        @output << ", " << temp << ", true)\n"
      end

      emit_literal(">")

      # children are emitted regardless of whether the tag is
      # self-closing. only the closing `</tag>` is suppressed for
      # self-closing tags.

      node.children.each { |c| emit_node(c) }
      unless SELF_CLOSING_TAGS.includes?(node.tag)
        emit_literal("</")
        emit_literal(node.tag)
        emit_literal(">")
      end

      emit_literal(" ") if node.ws_right
    end

    # Emits the merged `class="..."` attribute. Uses the literal
    # accumulator when every source is literal (the common case),
    # routes through `Slang::Runtime.emit_class` otherwise.
    #
    private def emit_class_merge(node : AST::Element, splat_temps : Array(String)) : Nil
      class_attrs = node.attrs.select { |a| a.name == "class" }
      has_dynamic = !class_attrs.empty? || !splat_temps.empty?

      if !has_dynamic
        return if node.classes.empty?
        emit_literal(" class=\"")
        emit_literal(node.classes.join(' '))
        emit_literal("\"")
        return
      end

      flush_literal
      @output << "::Slang::Runtime.emit_class(" << @buffer_name
      @output << ", " << node.classes.join(' ').dump
      class_attrs.each do |attr|
        @output << ", "
        emit_loc(attr.loc)
        @output << '(' << attr.value << ").to_s.presence"
      end
      splat_temps.each do |temp|
        @output << ", " << temp << "[\"class\"]?.try(&.to_s).try(&.presence)"
      end
      @output << ")\n"
    end

    private def emit_attr(attr : AST::Attribute) : Nil
      expr = attr.value
      if expr == "true"
        emit_literal(" ")
        emit_literal(attr.name)
        return
      end
      if expr == "false"
        return
      end
      if (literal = simple_string_literal(expr))
        emit_literal(" ")
        emit_literal(attr.name)
        emit_literal("=\"")
        emit_literal(::HTML.escape(literal))
        emit_literal("\"")
        return
      end
      flush_literal
      emit_loc(attr.loc)
      @output << "::Slang::Runtime.emit_attr(" << @buffer_name
      @output << ", " << attr.name.dump << ", (" << expr << "))\n"
    end

    # Returns the inner string if `expr` is a simple double-quoted
    # Crystal string literal -- no backslash escapes, no
    # interpolation. Conservative on purpose: false negatives just
    # fall through to the runtime helper, which is always correct.
    #
    private def simple_string_literal(expr : String) : String?
      return if expr.size < 2
      return unless expr.starts_with?('"') && expr.ends_with?('"')
      inner = expr[1..-2]
      return if inner.includes?('\\') || inner.includes?('"')
      # reject `#{...}` interpolation; bare `#` followed by anything
      # other than `{` is fine.
      i = 0
      while i < inner.size
        if inner[i] == '#' && i + 1 < inner.size && inner[i + 1] == '{'
          return
        end
        i += 1
      end
      inner
    end

    # ----- Output (= and ==) -----

    private def emit_output(node : AST::Output) : Nil
      emit_literal(" ") if node.ws_left

      flush_literal
      emit_loc(node.loc)

      if node.children.empty?
        if node.escape
          @output << "::HTML.escape((" << node.expr << ").to_s, " << @buffer_name << ")\n"
        else
          @output << '(' << node.expr << ").to_s(" << @buffer_name << ")\n"
        end
      else
        sub = fresh_sub_buffer
        @output << '(' << node.expr << '\n'
        @output << "String.build do |" << sub << "|\n"
        saved_buffer = @buffer_name
        @buffer_name = sub
        node.children.each { |c| emit_node(c) }
        flush_literal
        @buffer_name = saved_buffer
        @output << "end\n"
        @output << "end).to_s(" << @buffer_name << ")\n"
      end

      emit_literal(" ") if node.ws_right
    end

    # ----- Code (- lines) -----

    private def emit_code(node : AST::Code) : Nil
      flush_literal
      emit_loc(node.loc)
      @output << node.expr << '\n'

      node.children.each { |c| emit_node(c) }
      flush_literal

      node.branches.each do |branch|
        emit_loc(branch.loc)
        @output << branch.expr << '\n'
        branch.children.each { |c| emit_node(c) }
        flush_literal
      end

      if needs_end?(node)
        @output << "end\n"
      end
    end

    private def needs_end?(code : AST::Code) : Bool
      return false if code.branch
      !code.children.empty? || !code.branches.empty?
    end

    # ----- Text-bearing constructs -----

    private def emit_text_node(node : AST::Text) : Nil
      emit_text_parts(node.parts)
    end

    private def emit_text_block(node : AST::TextBlock) : Nil
      emit_text_parts(node.parts)
      emit_literal(" ") if node.kind.quote?
    end

    private def emit_raw_html(node : AST::RawHtml) : Nil
      emit_text_parts(node.parts)
    end

    private def emit_text_parts(parts : Array(AST::TextPart)) : Nil
      parts.each do |part|
        case part
        when AST::Literal
          if part.escape
            emit_literal(::HTML.escape(part.value))
          else
            emit_literal(part.value)
          end
        when AST::Interp
          flush_literal
          emit_loc(part.loc)
          if part.escape
            @output << "::HTML.escape((" << part.expr << ").to_s, " << @buffer_name << ")\n"
          else
            @output << '(' << part.expr << ").to_s(" << @buffer_name << ")\n"
          end
        else
          raise "Slang::CodeGen: unexpected text part #{part.class}"
        end
      end
    end

    # ----- Comments -----

    private def emit_visible_comment(node : AST::VisibleComment) : Nil
      emit_literal("<!--")
      emit_text_parts(node.parts)
      unless node.children.empty?
        node.children.each { |c| emit_node(c) }
        emit_literal("\n")
      end
      emit_literal("-->")
    end

    # ----- Doctype -----

    private def emit_doctype(node : AST::Doctype) : Nil
      emit_literal("<!DOCTYPE ")
      emit_literal(node.value)
      emit_literal(">")
    end

    # ----- Rawstuff -----

    # Emits `javascript:` / `css:` / `crystal:` blocks.
    #
    private def emit_rawstuff(node : AST::Rawstuff) : Nil
      case node.flavor
      in AST::RawstuffFlavor::JavaScript
        emit_literal("<script>")
        emit_text_parts(node.parts)
        emit_literal("</script>")
      in AST::RawstuffFlavor::CSS
        emit_literal("<style>")
        emit_text_parts(node.parts)
        emit_literal("</style>")
      in AST::RawstuffFlavor::Crystal
        flush_literal
        emit_loc(node.loc)
        node.parts.each do |part|
          case part
          when AST::Literal
            @output << part.value
          when AST::Interp
            # rawstuff Crystal bodies are verbatim source; the lexer
            # does not recognize `#{...}` interpolation inside them,
            # so this branch is unreachable in practice. guard
            # defensively.
            @output << "\#{" << part.expr << '}'
          else
            raise "Slang::CodeGen: unexpected text part #{part.class}"
          end
        end
        @output << '\n'
      end
    end
  end
end
