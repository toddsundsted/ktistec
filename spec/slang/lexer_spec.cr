require "spectator"

require "../../src/slang"

# collects all tokens
private def tokenize(source : String) : Array(Slang::Token)
  lexer = Slang::Lexer.new(source)
  tokens = [] of Slang::Token
  loop do
    tok = lexer.next_token
    tokens << tok
    break if tok.kind == Slang::TokenKind::EOF
  end
  tokens
end

# collect just kinds
private def kinds(source : String) : Array(Slang::TokenKind)
  tokenize(source).map(&.kind)
end

# collect (kind, value) pairs
private def pairs(source : String) : Array({Slang::TokenKind, String})
  tokenize(source).map { |t| {t.kind, t.value} }
end

# collect (kind, value, escape) triples
private def triples(source : String) : Array({Slang::TokenKind, String, Bool})
  tokenize(source).map { |t| {t.kind, t.value, t.escape} }
end

Spectator.describe Slang::Lexer do
  alias TK = Slang::TokenKind

  describe "#next_token" do
    it "returns EOF for empty input" do
      expect(kinds("")).to eq([TK::EOF])
    end

    it "treats whitespace-only input as no logical lines" do
      expect(kinds("   \n   \n")).to eq([TK::EOF])
    end

    it "returns EOF on repeated calls past the end" do
      lexer = Slang::Lexer.new("")
      3.times do
        expect(lexer.next_token.kind).to eq(TK::EOF)
      end
    end

    context "indentation" do
      it "emits no Indent/Dedent for a single line" do
        src = "div"
        expect(kinds(src)).to eq([
          TK::Element, TK::TagName, TK::Newline,
          TK::EOF,
        ])
      end

      it "emits Indent/Dedent around nested children" do
        src = "div\n  span"
        expect(kinds(src)).to eq([
          TK::Element, TK::TagName, TK::Newline,
          TK::Indent, TK::Element, TK::TagName, TK::Newline,
          TK::Dedent,
          TK::EOF,
        ])
      end

      it "flushes nested Dedents at EOF" do
        src = "a\n b\n  c"
        expect(kinds(src)).to eq([
          TK::Element, TK::TagName, TK::Newline,
          TK::Indent, TK::Element, TK::TagName, TK::Newline,
          TK::Indent, TK::Element, TK::TagName, TK::Newline,
          TK::Dedent, TK::Dedent,
          TK::EOF,
        ])
      end

      it "emits a Dedent for each level when indentation drops by multiple levels" do
        src = "a\n  b\n    c\nd"
        expect(kinds(src)).to eq([
          TK::Element, TK::TagName, TK::Newline,
          TK::Indent, TK::Element, TK::TagName, TK::Newline,
          TK::Indent, TK::Element, TK::TagName, TK::Newline,
          TK::Dedent, TK::Dedent,
          TK::Element, TK::TagName, TK::Newline,
          TK::EOF,
        ])
      end

      it "raises LexError on a tab in indentation" do
        expect { tokenize("div\n\tspan") }.to raise_error(Slang::LexError, "tab in indentation (use spaces only) at line 2, column 1")
      end

      it "raises LexError on misaligned dedent" do
        expect { tokenize("a\n    b\n  c") }.to raise_error(Slang::LexError, "misaligned indentation at line 3, column 1")
      end

      it "skips blank lines without disturbing the indent stack" do
        # `b` and `c` are siblings at column 3 with a blank line
        # between them. the blank must not trigger a dedent to
        # baseline (which would force a re-indent for `c`); the
        # stream stays one Indent / one Dedent total.
        expect(kinds("a\n  b\n\n  c")).to eq([
          TK::Element, TK::TagName, TK::Newline,
          TK::Indent,
          TK::Element, TK::TagName, TK::Newline,
          TK::Element, TK::TagName, TK::Newline,
          TK::Dedent,
          TK::EOF,
        ])
      end
    end

    context "line endings" do
      it "accepts CRLF as a line terminator" do
        src = "div\r\nspan"
        expect(kinds(src)).to eq([
          TK::Element, TK::TagName, TK::Newline,
          TK::Element, TK::TagName, TK::Newline,
          TK::EOF,
        ])
      end

      it "raises on a bare CR not followed by LF" do
        expect { tokenize("div\rspan") }.to raise_error(Slang::LexError, "expected `\\n` after `\\r` at line 1, column 4")
      end
    end
  end

  describe "element lines" do
    it "lexes a tag" do
      expect(pairs("div")).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes class shorthand" do
      expect(pairs("div.foo.bar")).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::ClassName, "foo"}, {TK::ClassName, "bar"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes id shorthand" do
      expect(pairs("div#main")).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::IdName, "main"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "interleaves shorthand classes and ids" do
      expect(pairs("div#a.b#c")).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::IdName, "a"}, {TK::ClassName, "b"}, {TK::IdName, "c"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes implicit-div (`.`) at line start" do
      expect(pairs(".foo")).to eq([
        {TK::Element, ""}, {TK::ClassName, "foo"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes implicit-div (`#`) at line start" do
      expect(pairs("#main")).to eq([
        {TK::Element, ""}, {TK::IdName, "main"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes whitespace controls" do
      expect(kinds("div<>")).to eq([
        TK::Element, TK::TagName, TK::WsLeft, TK::WsRight,
        TK::Newline, TK::EOF,
      ])
    end

    it "permits `:` in attribute names" do
      tokens = pairs(%(svg xmlns:xlink="http://example.com"))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "svg"},
        {TK::AttrName, "xmlns:xlink"}, {TK::AttrValue, %("http://example.com")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end
  end

  describe "unwrapped attributes" do
    it "lexes a single attribute" do
      tokens = pairs(%(div class="foo"))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::AttrName, "class"}, {TK::AttrValue, %("foo")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes multiple attributes" do
      tokens = pairs(%(input type="text" name="xyz"))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::AttrName, "type"}, {TK::AttrValue, %("text")},
        {TK::AttrName, "name"}, {TK::AttrValue, %("xyz")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "scans Crystal expressions" do
      tokens = pairs(%(div data=[1, 2]))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::AttrName, "data"}, {TK::AttrValue, "[1, 2]"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "scans Crystal string literals" do
      tokens = pairs(%(div title="hello world"))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::AttrName, "title"}, {TK::AttrValue, %("hello world")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "permits `::` in attribute values" do
      tokens = pairs("a href=Ktistec::ViewHelper.path Accounts")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "a"},
        {TK::AttrName, "href"},
        {TK::AttrValue, "Ktistec::ViewHelper.path"},
        {TK::TextLiteral, "Accounts"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "permits `:symbol` in attribute values" do
      tokens = pairs("div data=:foo")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::AttrName, "data"}, {TK::AttrValue, ":foo"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "tolerates multiple spaces between attributes" do
      tokens = pairs(%(div  href="/x"  class="foo"))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::AttrName, "href"}, {TK::AttrValue, %("/x")},
        {TK::AttrName, "class"}, {TK::AttrValue, %("foo")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "raises on missing value after `=`" do
      expect { tokenize(%(div class= more)) }.to raise_error(Slang::LexError, "expected attribute value after `=` at line 1, column 11")
    end
  end

  describe "wrapped attributes" do
    it "lexes parenthesized attributes" do
      tokens = pairs(%(input(type="text" name="xyz")))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::AttrName, "type"}, {TK::AttrValue, %("text")},
        {TK::AttrName, "name"}, {TK::AttrValue, %("xyz")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes square-bracket attributes" do
      tokens = pairs(%(input[type="text"]))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::AttrName, "type"}, {TK::AttrValue, %("text")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes brace attributes" do
      tokens = pairs(%(input{type="text"}))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::AttrName, "type"}, {TK::AttrValue, %("text")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "permits attribute values across newlines inside a wrapper" do
      tokens = pairs("input(type=\"text\"\nname=\"xyz\")")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::AttrName, "type"}, {TK::AttrValue, %("text")},
        {TK::AttrName, "name"}, {TK::AttrValue, %("xyz")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "permits `:` in wrapped attribute names" do
      tokens = pairs(%(svg(xmlns:xlink="http://example.com")))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "svg"},
        {TK::AttrName, "xmlns:xlink"}, {TK::AttrValue, %("http://example.com")},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "raises on a mismatched wrapper closer" do
      expect { tokenize("input(type=\"text\"]") }.to raise_error(Slang::LexError, "mismatched attribute wrapper closer (expected `)`) at line 1, column 18")
    end

    it "raises on an unterminated wrapper" do
      expect { tokenize("input(type=\"text\"") }.to raise_error(Slang::LexError, "unterminated attribute wrapper (expected `)`) at line 1, column 6")
    end
  end

  describe "splat" do
    it "lexes a splat after a tag" do
      tokens = pairs("input *attrs")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::SplatExpr, "attrs"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes a splat among unwrapped attrs" do
      tokens = pairs("input class=\"foo\" *more")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "input"},
        {TK::AttrName, "class"}, {TK::AttrValue, %("foo")},
        {TK::SplatExpr, "more"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "raises on bare `*`" do
      expect { tokenize("div *") }.to raise_error(Slang::LexError, "expected splat expression after `*` at line 1, column 5")
    end
  end

  describe "inline children (`:`)" do
    it "lexes inline `:`" do
      tokens = pairs("li.first: a Hello")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "li"}, {TK::ClassName, "first"},
        {TK::InlineColon, ""},
        {TK::Element, ""}, {TK::TagName, "a"},
        {TK::TextLiteral, "Hello"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "lexes a chain of inline `:`" do
      tokens = pairs("li: a: span text")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "li"},
        {TK::InlineColon, ""},
        {TK::Element, ""}, {TK::TagName, "a"},
        {TK::InlineColon, ""},
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::TextLiteral, "text"},
        {TK::Newline, ""}, {TK::EOF, ""},
      ])
    end

    it "raises on bare `:` at start of line" do
      expect { tokenize(": foo") }.to raise_error(Slang::LexError, "unexpected `:` at start of line at line 1, column 1")
    end
  end

  describe "trailing text" do
    it "captures plain trailing text" do
      tokens = pairs("span Hello world")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::TextLiteral, "Hello world"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "marks trailing text starting with `<` as raw" do
      tokens = triples("div <ah>")
      expect(tokens).to eq([
        {TK::Element, "", true},
        {TK::TagName, "div", true},
        {TK::TextLiteral, "<ah>", false},
        {TK::Newline, "", true},
        {TK::EOF, "", true},
      ])
    end

    it "marks trailing text after script as raw" do
      tokens = triples(%(script var num1 = 8*4;))
      expect(tokens).to eq([
        {TK::Element, "", true},
        {TK::TagName, "script", true},
        {TK::TextLiteral, "var num1 = 8*4;", false},
        {TK::Newline, "", true},
        {TK::EOF, "", true},
      ])
    end

    it "segments interpolation into fragments" do
      tokens = pairs("span Hello \#{name}!")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::TextLiteral, "Hello "},
        {TK::InterpExpr, "name"},
        {TK::TextLiteral, "!"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "uses `\\#` to escape interpolation" do
      tokens = pairs(%q(span Hello \#{name}))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::TextLiteral, "Hello \#{name}"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "uses `\\=` to escape `=`" do
      tokens = pairs(%q(span hello \= world))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::TextLiteral, "hello = world"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "scans Crystal string literals inside interpolation" do
      # `"world"` inside the interpolation must not break out early.
      tokens = pairs("span \#{p(\"world\")}")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::InterpExpr, %(p("world"))},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end
  end

  describe "output (`=` and `==`)" do
    it "lexes `= EXPR`" do
      tokens = pairs("= 1 + 2")
      expect(tokens).to eq([
        {TK::Output, ""},
        {TK::OutputExpr, "1 + 2"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes `== EXPR`" do
      tokens = pairs(%q(== "<a>"))
      expect(tokens).to eq([
        {TK::OutputRaw, ""},
        {TK::OutputExpr, %q("<a>")},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes inline `=` after element" do
      tokens = pairs("span = name")
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::Output, ""},
        {TK::OutputExpr, "name"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes inline `==` after element" do
      tokens = pairs(%q(div == "<ah>"))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::OutputRaw, ""},
        {TK::OutputExpr, %q("<ah>")},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes inline `=` directly after a tag name (no leading space)" do
      tokens = pairs(%q(span= name))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::Output, ""},
        {TK::OutputExpr, "name"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes inline `==` directly after a tag name (no leading space)" do
      tokens = pairs(%q(span== name))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::OutputRaw, ""},
        {TK::OutputExpr, "name"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes inline `==` directly after class shorthand (no leading space)" do
      tokens = pairs(%q(span.foo== name))
      expect(tokens).to eq([
        {TK::Element, ""}, {TK::TagName, "span"},
        {TK::ClassName, "foo"},
        {TK::OutputRaw, ""},
        {TK::OutputExpr, "name"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes whitespace controls" do
      tokens = pairs("=< name")
      expect(tokens).to eq([
        {TK::Output, ""},
        {TK::WsLeft, ""},
        {TK::OutputExpr, "name"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end
  end

  describe "code (`-`)" do
    it "lexes a code line" do
      expect(pairs("- x = 5")).to eq([
        {TK::Code, ""},
        {TK::CodeExpr, "x = 5"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes inline `-` after element" do
      expect(pairs("div - [1,2,3].each do |n|")).to eq([
        {TK::Element, ""}, {TK::TagName, "div"},
        {TK::Code, ""},
        {TK::CodeExpr, "[1,2,3].each do |n|"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "captures `|` as part of a code-line expression" do
      expect(pairs("- arr.each do |n|")).to eq([
        {TK::Code, ""},
        {TK::CodeExpr, "arr.each do |n|"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end
  end

  describe "text blocks (`|` and `'`)" do
    it "lexes a single-line `|` block" do
      tokens = pairs("| Hello")
      expect(tokens).to eq([
        {TK::TextBlock, ""},
        {TK::TextLiteral, "Hello"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes a single-line `'` block" do
      tokens = pairs("' Hello")
      expect(tokens).to eq([
        {TK::TextBlockSpace, ""},
        {TK::TextLiteral, "Hello"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "absorbs continuation lines" do
      tokens = tokenize("| Line one.\n  Line two.\n    Line three.")
      literals = tokens.select { |t| t.kind == TK::TextLiteral }.map(&.value)
      expect(literals).to eq([
        "Line one.",
        "\n",
        "Line two.",
        "\n  ",
        "Line three.",
      ])
    end

    it "ends a text block when a line dedents" do
      tokens = tokenize("| Line one.\n  Line two.\ndiv")
      kinds = tokens.map(&.kind)
      expect(kinds).to eq([
        TK::TextBlock,
        TK::TextLiteral, # Line one.
        TK::TextLiteral, # \n
        TK::TextLiteral, # Line two.
        TK::Newline,
        TK::Element, TK::TagName,
        TK::Newline,
        TK::EOF,
      ])
    end

    it "marks text-block content as escape=false" do
      tokens = triples("| <ah>")
      expect(tokens).to eq([
        {TK::TextBlock, "", true},
        {TK::TextLiteral, "<ah>", false},
        {TK::Newline, "", true},
        {TK::EOF, "", true},
      ])
    end

    it "allows interpolation in text blocks" do
      tokens = triples("| Hello \#{name}!")
      expect(tokens).to eq([
        {TK::TextBlock, "", true},
        {TK::TextLiteral, "Hello ", false},
        {TK::InterpExpr, "name", false},
        {TK::TextLiteral, "!", false},
        {TK::Newline, "", true},
        {TK::EOF, "", true},
      ])
    end
  end

  describe "raw HTML lines" do
    it "lexes a `<` line as raw HTML" do
      tokens = triples("<div>verbatim</div>")
      expect(tokens).to eq([
        {TK::RawHtml, "", true},
        {TK::TextLiteral, "<div>verbatim</div>", false},
        {TK::Newline, "", true},
        {TK::EOF, "", true},
      ])
    end
  end

  describe "comments" do
    it "lexes a hidden comment" do
      tokens = pairs("/ this is hidden")
      expect(tokens).to eq([
        {TK::CommentHidden, ""},
        {TK::TextLiteral, "this is hidden"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes a visible comment (`/!`)" do
      tokens = pairs("/! this is visible")
      expect(tokens).to eq([
        {TK::CommentVisible, ""},
        {TK::TextLiteral, "this is visible"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes a conditional comment (`/[...]`)" do
      tokens = pairs("/[if IE]")
      expect(tokens).to eq([
        {TK::CommentConditional, ""},
        {TK::TextLiteral, "if IE"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "raises on an unterminated conditional comment" do
      expect { tokenize("/[if IE\n") }.to raise_error(Slang::LexError, "unterminated conditional comment at line 1, column 1")
    end

    it "raises on text after the closing `]` of a conditional comment" do
      expect { tokenize("/[if IE] something") }.to raise_error(Slang::LexError, "unexpected text after `]` in conditional comment at line 1, column 10")
    end

    it "tolerates trailing whitespace after the closing `]` of a conditional comment" do
      tokens = tokenize("/[if IE]   ")
      expect(tokens.map(&.kind)).to eq([
        TK::CommentConditional,
        TK::TextLiteral,
        TK::Newline,
        TK::EOF,
      ])
    end
  end

  describe "doctype" do
    it "lexes `doctype html`" do
      tokens = pairs("doctype html")
      expect(tokens).to eq([
        {TK::Doctype, ""},
        {TK::TextLiteral, "html"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "lexes a doctype with arbitrary value" do
      tokens = pairs("doctype xml-strict")
      expect(tokens).to eq([
        {TK::Doctype, ""},
        {TK::TextLiteral, "xml-strict"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end
  end

  describe "rawstuff blocks" do
    it "lexes `javascript:` with verbatim children" do
      tokens = triples("javascript:\n  var x = 1;\n  console.log(x);")
      expect(tokens).to eq([
        {TK::Element, "", true},
        {TK::TagName, "javascript:", true},
        {TK::TextLiteral, "var x = 1;", false},
        {TK::TextLiteral, "\nconsole.log(x);", false},
        {TK::Newline, "", true},
        {TK::EOF, "", true},
      ])
    end

    it "ends a rawstuff body when indentation drops to or below the opener" do
      tokens = pairs("javascript:\n  var x = 1;\np next sibling")
      expect(tokens).to eq([
        {TK::Element, ""},
        {TK::TagName, "javascript:"},
        {TK::TextLiteral, "var x = 1;"},
        {TK::Newline, ""},
        {TK::Element, ""},
        {TK::TagName, "p"},
        {TK::TextLiteral, "next sibling"},
        {TK::Newline, ""},
        {TK::EOF, ""},
      ])
    end

    it "preserves relative indentation" do
      tokens = tokenize("javascript:\n  var x = 1;\n    var y = 2;")
      lits = tokens.select { |t| t.kind == TK::TextLiteral }
      expect(lits.map(&.value)).to eq(["var x = 1;", "\n  var y = 2;"])
    end
  end

  describe "position tracking" do
    it "records line and column for the first byte of each token" do
      tokens = tokenize("div\n  span")
      div = tokens[1]
      span = tokens[4]
      expect({div.line, div.column}).to eq({1, 1})
      expect({span.line, span.column}).to eq({2, 3})
    end

    it "records column for shorthand classes" do
      tokens = tokenize("div.foo")
      cls = tokens[2]
      expect({cls.line, cls.column}).to eq({1, 4})
    end
  end
end
