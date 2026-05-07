require "spectator"

require "../../src/slang"

private alias AST = Slang::AST

private def parse(source : String) : AST::Document
  Slang::Parser.parse(source)
end

private def parse_one(source : String) : AST::Node
  parse(source).nodes.first
end

private def parse_element(source : String) : AST::Element
  parse_one(source).as(AST::Element)
end

private def literal_parts(parts : Array(AST::TextPart)) : Array({String, Bool})
  parts.map do |part|
    lit = part.as(AST::Literal)
    {lit.value, lit.escape}
  end
end

Spectator.describe Slang::Parser do
  describe ".parse" do
    it "returns an empty document" do
      expect(parse("").nodes).to be_empty
    end

    it "returns an empty document" do
      expect(parse("   \n   \n").nodes).to be_empty
    end

    context "elements" do
      it "parses a tag name" do
        el = parse_element("div")
        expect(el.tag).to eq("div")
      end

      it "treats `.foo` as an implicit div" do
        el = parse_element(".foo")
        expect(el.tag).to eq("div")
      end

      it "treats `#main` as an implicit div" do
        el = parse_element("#main")
        expect(el.tag).to eq("div")
      end

      it "captures the source location of an indented element" do
        doc = parse("outer\n  inner")
        inner = doc.nodes.first.as(AST::Element).children.first.as(AST::Element)
        expect(inner.loc.line).to eq(2)
        expect(inner.loc.column).to eq(3)
      end

      it "parses multiple top-level siblings" do
        doc = parse("div\nspan\np")
        expect(doc.nodes.map { |n| n.as(AST::Element).tag }).to eq(["div", "span", "p"])
      end

      context "shorthand" do
        it "parses class shorthand" do
          el = parse_element("div.foo")
          expect(el.classes).to eq(["foo"])
        end

        it "accumulates multiple class shorthand entries in source order" do
          el = parse_element("div.foo.bar.baz")
          expect(el.classes).to eq(["foo", "bar", "baz"])
        end

        it "parses id shorthand" do
          el = parse_element("div#main")
          expect(el.id).to eq("main")
        end

        it "rejects multiple id shorthands" do
          expect { parse("div#a#b") }.to raise_error(Slang::ParseError, "element has multiple `#id` shorthands at line 1, column 6")
        end
      end

      context "whitespace controls" do
        it "parses `<` as ws_left" do
          el = parse_element("div<")
          expect(el.ws_left).to be_true
          expect(el.ws_right).to be_false
        end

        it "parses `>` as ws_right" do
          el = parse_element("div>")
          expect(el.ws_right).to be_true
          expect(el.ws_left).to be_false
        end

        it "parses `<>` as both" do
          el = parse_element("div<>")
          expect(el.ws_left).to be_true
          expect(el.ws_right).to be_true
        end
      end

      context "attributes" do
        it "parses a single attribute" do
          el = parse_element(%(input type="text"))
          expect(el.attrs.size).to eq(1)
          expect(el.attrs.first.name).to eq("type")
          expect(el.attrs.first.value).to eq(%("text"))
        end

        it "parses multiple attributes" do
          el = parse_element(%(input type="text" name="xyz"))
          expect(el.attrs.map(&.name)).to eq(["type", "name"])
        end

        it "parses wrapped attributes" do
          el = parse_element(%(input(type="text" name="xyz")))
          expect(el.attrs.map(&.name)).to eq(["type", "name"])
        end

        it "captures attribute value as a Crystal expression" do
          el = parse_element("a href=some.path")
          expect(el.attrs.first.value).to eq("some.path")
        end

        it "captures the source location of the attribute value expression" do
          el = parse_element(%(input type="text"))
          attr = el.attrs.first
          expect(attr.loc.line).to eq(1)
          expect(attr.loc.column).to eq(12)
        end
      end

      context "splat" do
        it "parses a splat" do
          el = parse_element("input *attrs")
          expect(el.splats.size).to eq(1)
          expect(el.splats.first.expr).to eq("attrs")
        end

        it "captures splat alongside named attributes" do
          el = parse_element(%(input type="text" *attrs))
          expect(el.attrs.map(&.name)).to eq(["type"])
          expect(el.splats.map(&.expr)).to eq(["attrs"])
        end

        it "accumulates multiple splats inside a wrapper" do
          el = parse_element("input(*a *b)")
          expect(el.splats.map(&.expr)).to eq(["a", "b"])
        end
      end

      context "trailing text" do
        it "captures plain trailing text" do
          el = parse_element("span Hello World")
          expect(el.children.size).to eq(1)
          text = el.children.first.as(AST::Text)
          expect(literal_parts(text.parts)).to eq([{"Hello World", false}])
        end

        it "captures interpolation in trailing text" do
          el = parse_element(%(span Hello \#{name}!))
          text = el.children.first.as(AST::Text)
          parts = text.parts
          expect(parts.size).to eq(3)
          expect(parts[0].as(AST::Literal).value).to eq("Hello ")
          expect(parts[1].as(AST::Interp).expr).to eq("name")
          expect(parts[2].as(AST::Literal).value).to eq("!")
        end

        it "marks `<`-prefixed trailing text as unescaped" do
          el = parse_element("p <em>raw</em>")
          text = el.children.first.as(AST::Text)
          expect(text.parts.first.as(AST::Literal).escape).to be_false
        end
      end

      context "indented children" do
        it "attaches a single indented child" do
          el = parse_element("div\n  span")
          expect(el.children.size).to eq(1)
          inner = el.children.first.as(AST::Element)
          expect(inner.tag).to eq("span")
        end

        it "attaches multiple sibling children" do
          el = parse_element("ul\n  li\n  li\n  li")
          expect(el.children.map(&.as(AST::Element).tag)).to eq(["li", "li", "li"])
        end

        it "nests children at multiple depths" do
          el = parse_element("a\n  b\n    c")
          b = el.children.first.as(AST::Element)
          c = b.children.first.as(AST::Element)
          expect(b.tag).to eq("b")
          expect(c.tag).to eq("c")
        end

        it "appends trailing text before indented children" do
          el = parse_element("p Greeting\n  span name")
          expect(el.children.size).to eq(2)
          expect(el.children[0]).to be_a(AST::Text)
          expect(el.children[1]).to be_a(AST::Element)
        end
      end

      context "script children" do
        it "rejects bare `script` with trailing text" do
          expect { parse("script var x = 1;") }.to raise_error(
            Slang::ParseError,
            /^`<script>` with executable type cannot have Slang children/,
          )
        end

        it "rejects bare `script` with an indent block" do
          expect { parse("script\n  var x = 1;") }.to raise_error(Slang::ParseError, /script/)
        end

        it "rejects `script` with an inline child" do
          expect { parse(%(script: span hi)) }.to raise_error(Slang::ParseError, /script/)
        end

        it "rejects `script type=\"text/javascript\"`" do
          expect { parse(%(script type="text/javascript"\n  var x = 1;)) }.to raise_error(
            Slang::ParseError,
            /script.*executable/,
          )
        end

        it "rejects `script type=\"module\"`" do
          expect { parse(%(script type="module"\n  var x = 1;)) }.to raise_error(
            Slang::ParseError,
            /script/,
          )
        end

        it "rejects `script` with a Crystal-expression `type`" do
          expect { parse(%(script type=some_var\n  var x = 1;)) }.to raise_error(
            Slang::ParseError,
            /script/,
          )
        end

        it "accepts `script type=\"application/json\"` with children" do
          el = parse_element(%(script type="application/json"\n  == data.to_json))
          expect(el.tag).to eq("script")
          expect(el.children.size).to eq(1)
        end

        it "accepts `script type=\"application/ld+json\"` with children" do
          el = parse_element(%(script type="application/ld+json"\n  == graph.to_json))
          expect(el.tag).to eq("script")
          expect(el.children.size).to eq(1)
        end

        it "accepts a bare `script src=\"...\"` with no body" do
          el = parse_element(%(script src="/x.js"))
          expect(el.tag).to eq("script")
          expect(el.children).to be_empty
        end

        it "is case-insensitive on the `type` value" do
          el = parse_element(%(script type="Application/JSON"\n  == data.to_json))
          expect(el.tag).to eq("script")
        end

        it "rejects bodyless `script` without a named `src`" do
          expect { parse(%(script type="text/javascript")) }.to raise_error(
            Slang::ParseError,
            /bodyless .*requires a named `src=`/,
          )
        end

        it "rejects bodyless `script`" do
          expect { parse("script") }.to raise_error(
            Slang::ParseError,
            /bodyless .*requires a named `src=`/,
          )
        end
      end

      context "style children" do
        it "rejects `style` with trailing text" do
          expect { parse("style h1 { color: red; }") }.to raise_error(
            Slang::ParseError,
            /^`<style>` elements are banned/,
          )
        end

        it "rejects `style` with an indent block" do
          expect { parse("style\n  h1 { color: red; }") }.to raise_error(Slang::ParseError, /style/)
        end

        it "rejects bodyless `style` with attributes" do
          expect { parse(%(style media="print")) }.to raise_error(
            Slang::ParseError,
            /^`<style>` elements are banned/,
          )
        end

        it "rejects bodyless `style`" do
          expect { parse("style") }.to raise_error(
            Slang::ParseError,
            /^`<style>` elements are banned/,
          )
        end
      end

      context "void element children" do
        it "rejects `img` with trailing text" do
          expect { parse(%(img src="/x" alt text)) }.to raise_error(
            Slang::ParseError,
            /^void element `<img>` cannot have Slang children/,
          )
        end

        it "rejects `br` with inline `:` child" do
          expect { parse(%(br: a href="/x" Click)) }.to raise_error(
            Slang::ParseError,
            /^void element `<br>` cannot have Slang children/,
          )
        end

        it "rejects `br` with an indent block" do
          expect { parse("br\n  span hi") }.to raise_error(
            Slang::ParseError,
            /^void element `<br>` cannot have Slang children/,
          )
        end

        it "rejects `input` with an inline `:` child" do
          expect { parse(%(input: span hi)) }.to raise_error(
            Slang::ParseError,
            /^void element `<input>` cannot have Slang children/,
          )
        end

        it "rejects `link` with an indent block" do
          expect { parse(%(link rel="stylesheet" href="/x.css"\n  span hi)) }.to raise_error(
            Slang::ParseError,
            /^void element `<link>` cannot have Slang children/,
          )
        end

        it "accepts a bodyless `br`" do
          el = parse_element("br")
          expect(el.tag).to eq("br")
          expect(el.children).to be_empty
        end

        it "accepts a bodyless `img`" do
          el = parse_element(%(img src="/x" alt="..."))
          expect(el.tag).to eq("img")
          expect(el.children).to be_empty
        end

        it "accepts a bodyless `input`" do
          el = parse_element(%(input type="text" name="x"))
          expect(el.tag).to eq("input")
          expect(el.children).to be_empty
        end
      end

      context "inline child" do
        it "nests an inline element as a child" do
          el = parse_element("li: a")
          expect(el.children.size).to eq(1)
          inner = el.children.first.as(AST::Element)
          expect(inner.tag).to eq("a")
        end

        it "places trailing text on the inline child, not the outer element" do
          el = parse_element("li: a Click")
          a = el.children.first.as(AST::Element)
          text = a.children.first.as(AST::Text)
          expect(literal_parts(text.parts)).to eq([{"Click", false}])
        end

        it "attaches an indent block to the inline child" do
          el = parse_element("li: a\n  span inner")
          a = el.children.first.as(AST::Element)
          span = a.children.first.as(AST::Element)
          expect(span.tag).to eq("span")
        end

        it "chains multiple inline elements" do
          el = parse_element("li: a: span text")
          a = el.children.first.as(AST::Element)
          span = a.children.first.as(AST::Element)
          text = span.children.first.as(AST::Text)
          expect(a.tag).to eq("a")
          expect(span.tag).to eq("span")
          expect(literal_parts(text.parts)).to eq([{"text", false}])
        end

        it "supports an inline element opening with class shorthand" do
          el = parse_element("li: .marker")
          inner = el.children.first.as(AST::Element)
          expect(inner.tag).to eq("div")
          expect(inner.classes).to eq(["marker"])
        end
      end

      context "inline output" do
        it "captures `=` as a child" do
          el = parse_element("span = name")
          output = el.children.first.as(AST::Output)
          expect(output.expr).to eq("name")
          expect(output.escape).to be_true
        end

        it "captures `==` as a raw child" do
          el = parse_element("span == raw_html")
          output = el.children.first.as(AST::Output)
          expect(output.expr).to eq("raw_html")
          expect(output.escape).to be_false
        end

        it "captures whitespace controls" do
          el = parse_element("span =< name")
          output = el.children.first.as(AST::Output)
          expect(output.ws_left).to be_true
        end

        it "attaches an indent block to the inline output" do
          el = parse_element("span = form_for do |form|\n  input")
          output = el.children.first.as(AST::Output)
          inner = output.children.first.as(AST::Element)
          expect(output.expr).to eq("form_for do |form|")
          expect(inner.tag).to eq("input")
        end

        it "captures `=` after `:`" do
          el = parse_element("li: = name")
          output = el.children.first.as(AST::Output)
          expect(output.expr).to eq("name")
        end
      end

      context "inline code" do
        it "captures `-` as a child" do
          el = parse_element("ul - foo.bar")
          code = el.children.first.as(AST::Code)
          expect(code.expr).to eq("foo.bar")
        end

        it "attaches an indent block to the inline code" do
          el = parse_element("ul - [1, 2].each do |n|\n  li = n")
          code = el.children.first.as(AST::Code)
          inner = code.children.first.as(AST::Element)
          expect(code.expr).to eq("[1, 2].each do |n|")
          expect(inner.tag).to eq("li")
        end
      end
    end

    context "top-level output" do
      it "parses `= expr` as an Output node" do
        node = parse_one("= name").as(AST::Output)
        expect(node.expr).to eq("name")
        expect(node.escape).to be_true
      end

      it "parses `== expr` as a raw Output node" do
        node = parse_one("== raw_html").as(AST::Output)
        expect(node.expr).to eq("raw_html")
        expect(node.escape).to be_false
      end

      it "captures whitespace controls" do
        node = parse_one("=< name").as(AST::Output)
        expect(node.ws_left).to be_true
      end

      it "attaches an indent block as children" do
        node = parse_one("= form_for do |form|\n  input").as(AST::Output)
        inner = node.children.first.as(AST::Element)
        expect(node.expr).to eq("form_for do |form|")
        expect(inner.tag).to eq("input")
      end
    end

    context "top-level code" do
      it "parses `- expr` as a Code node" do
        node = parse_one("- x = 5").as(AST::Code)
        expect(node.expr).to eq("x = 5")
      end

      it "attaches an indent block as children" do
        node = parse_one("- if x\n  p Yes").as(AST::Code)
        inner = node.children.first.as(AST::Element)
        expect(node.expr).to eq("if x")
        expect(inner.tag).to eq("p")
      end
    end

    context "text blocks" do
      it "parses `|` as a Pipe text block" do
        node = parse_one("| Hello world").as(AST::TextBlock)
        expect(node.kind).to eq(AST::TextBlockKind::Pipe)
        expect(literal_parts(node.parts)).to eq([{"Hello world", false}])
      end

      it "parses `'` as a Quote text block" do
        node = parse_one("' Hello world").as(AST::TextBlock)
        expect(node.kind).to eq(AST::TextBlockKind::Quote)
        expect(literal_parts(node.parts)).to eq([{"Hello world", false}])
      end

      it "captures interpolation in the text block" do
        node = parse_one(%(| Hello \#{name}!)).as(AST::TextBlock)
        parts = node.parts
        expect(parts.size).to eq(3)
        expect(parts[0].as(AST::Literal).value).to eq("Hello ")
        expect(parts[1].as(AST::Interp).expr).to eq("name")
        expect(parts[2].as(AST::Literal).value).to eq("!")
      end

      it "folds continuation lines into the parts" do
        node = parse_one("| Line one.\n  Line two.").as(AST::TextBlock)
        expect(node.parts.size).to be_gt(1)
        joined = node.parts.compact_map { |p| p.as?(AST::Literal).try(&.value) }.join
        expect(joined).to eq("Line one.\nLine two.")
      end

      it "marks all parts as unescaped" do
        node = parse_one("| Line one.\n  Line two.").as(AST::TextBlock)
        expect(node.parts.map(&.as(AST::Literal).escape)).to all(be_false)
      end
    end

    context "raw HTML lines" do
      it "parses `<div>...</div>` as a RawHtml node" do
        node = parse_one("<div>verbatim</div>").as(AST::RawHtml)
        expect(literal_parts(node.parts)).to eq([{"<div>verbatim</div>", false}])
      end

      it "captures interpolation in raw HTML" do
        node = parse_one(%(<span>\#{name}</span>)).as(AST::RawHtml)
        parts = node.parts
        expect(parts.size).to eq(3)
        expect(parts[1].as(AST::Interp).expr).to eq("name")
      end

      it "marks all parts as unescaped" do
        node = parse_one("<p>literal & ampersand</p>").as(AST::RawHtml)
        expect(node.parts.map(&.as(AST::Literal).escape)).to all(be_false)
      end
    end

    context "hidden comments" do
      it "parses `/ ...` as a HiddenComment node" do
        node = parse_one("/ this is hidden")
        expect(node).to be_a(AST::HiddenComment)
      end

      it "absorbs indented children" do
        node = parse_one("/ outer\n  div content").as(AST::HiddenComment)
        expect(node.children.size).to eq(1)
        expect(node.children.first.as(AST::Element).tag).to eq("div")
      end
    end

    context "visible comments" do
      it "parses `/!` as a VisibleComment node with literal text" do
        node = parse_one("/! visible note").as(AST::VisibleComment)
        expect(literal_parts(node.parts)).to eq([{"visible note", false}])
      end

      it "captures interpolation in the comment body" do
        node = parse_one(%(/! hello \#{name})).as(AST::VisibleComment)
        expect(node.parts.size).to eq(2)
        expect(node.parts[0].as(AST::Literal).value).to eq("hello ")
        expect(node.parts[1].as(AST::Interp).expr).to eq("name")
      end

      it "rejects indented children" do
        expect { parse("/! wrapper\n  p inner") }.to raise_error(
          Slang::ParseError,
          /^visible comments \(`\/!`\) cannot have indented children/,
        )
      end

      it "rejects an indented `|` text block" do
        expect { parse("/! wrapper\n  | extra body") }.to raise_error(
          Slang::ParseError,
          /^visible comments \(`\/!`\) cannot have indented children/,
        )
      end

      it "rejects indented `==` output" do
        expect { parse(%(/! wrapper\n  == "x")) }.to raise_error(
          Slang::ParseError,
          /^visible comments \(`\/!`\) cannot have indented children/,
        )
      end

      it "rejects indented `=` output" do
        expect { parse(%(/! wrapper\n  = SafeHTML.assert_safe("--><script>"))) }.to raise_error(
          Slang::ParseError,
          /^visible comments \(`\/!`\) cannot have indented children/,
        )
      end
    end

    context "doctype" do
      it "parses `doctype html`" do
        node = parse_one("doctype html").as(AST::Doctype)
        expect(node.value).to eq("html")
      end

      it "captures the rest of the line verbatim" do
        node = parse_one("doctype xml").as(AST::Doctype)
        expect(node.value).to eq("xml")
      end
    end

    context "rawstuff blocks" do
      it "parses `javascript:` as a JavaScript-flavored Rawstuff" do
        node = parse_one("javascript:\n  var x = 1;").as(AST::Rawstuff)
        expect(node.flavor).to eq(AST::RawstuffFlavor::JavaScript)
      end

      it "parses `css:` as a CSS-flavored Rawstuff" do
        node = parse_one("css:\n  .foo { color: red; }").as(AST::Rawstuff)
        expect(node.flavor).to eq(AST::RawstuffFlavor::CSS)
      end

      it "parses `crystal:` as a Crystal-flavored Rawstuff" do
        node = parse_one("crystal:\n  x = 5").as(AST::Rawstuff)
        expect(node.flavor).to eq(AST::RawstuffFlavor::Crystal)
      end

      it "captures continuation-line content verbatim" do
        node = parse_one("javascript:\n  var x = 1;\n  console.log(x);").as(AST::Rawstuff)
        joined = node.parts.compact_map { |p| p.as?(AST::Literal).try(&.value) }.join
        expect(joined).to eq("var x = 1;\nconsole.log(x);")
      end

      it "marks all rawstuff parts as unescaped" do
        node = parse_one("css:\n  body { color: red; }").as(AST::Rawstuff)
        expect(node.parts.map(&.as(AST::Literal).escape)).to all(be_false)
      end

      it "nests under an element" do
        outer = parse_element("div\n  javascript:\n    var x = 1;")
        rawstuff = outer.children.first.as(AST::Rawstuff)
        expect(rawstuff.flavor).to eq(AST::RawstuffFlavor::JavaScript)
      end
    end

    context "branchable detection" do
      it "tags `if EXPR` as If branchable" do
        node = parse_one("- if x > 0").as(AST::Code)
        expect(node.branchable).to eq(AST::BranchableKind::If)
        expect(node.branch).to be_nil
      end

      it "tags `case EXPR` as Case branchable" do
        node = parse_one("- case foo").as(AST::Code)
        expect(node.branchable).to eq(AST::BranchableKind::Case)
        expect(node.branch).to be_nil
      end

      it "tags `begin` (no expression) as Begin branchable" do
        node = parse_one("- begin\n  x = 1").as(AST::Code)
        expect(node.branchable).to eq(AST::BranchableKind::Begin)
        expect(node.branch).to be_nil
      end

      it "tags `else` as Else branch" do
        doc = parse("- if x\n- else")
        host = doc.nodes.first.as(AST::Code)
        expect(host.branches.first.branch).to eq(AST::BranchKind::Else)
      end

      it "does not tag `if?` as branchable" do
        node = parse_one("- foo.if?").as(AST::Code)
        expect(node.branchable).to be_nil
      end

      it "does not tag `iffy` as branchable" do
        node = parse_one("- iffy = 5").as(AST::Code)
        expect(node.branchable).to be_nil
      end
    end

    context "branchable attachment" do
      it "attaches `elsif` and `else` to `if`" do
        doc = parse("- if x\n  p A\n- elsif y\n  p B\n- else\n  p C")
        code = doc.nodes.first.as(AST::Code)
        expect(code.branchable).to eq(AST::BranchableKind::If)
        expect(code.branches.map(&.branch)).to eq([
          AST::BranchKind::Elsif,
          AST::BranchKind::Else,
        ])
      end

      it "attaches `when` and `else` to `case`" do
        doc = parse("- case x\n- when 1\n  p A\n- when 2\n  p B\n- else\n  p C")
        code = doc.nodes.first.as(AST::Code)
        expect(code.branchable).to eq(AST::BranchableKind::Case)
        expect(code.branches.map(&.branch)).to eq([
          AST::BranchKind::When,
          AST::BranchKind::When,
          AST::BranchKind::Else,
        ])
      end

      it "attaches `rescue` and `ensure` to `begin`" do
        doc = parse("- begin\n  body\n- rescue\n  rescue_body\n- ensure\n  cleanup")
        code = doc.nodes.first.as(AST::Code)
        expect(code.branchable).to eq(AST::BranchableKind::Begin)
        expect(code.branches.map(&.branch)).to eq([
          AST::BranchKind::Rescue,
          AST::BranchKind::Ensure,
        ])
      end

      it "rejects an orphan `else` with no preceding branchable" do
        expect { parse("- else") }.to raise_error(Slang::ParseError, "branch `else` has no matching preceding branchable at line 1, column 3")
      end

      it "rejects `when` after `if` (incompatible branchable)" do
        expect { parse("- if x\n- when y") }.to raise_error(Slang::ParseError, "branch `when` has no matching preceding branchable at line 2, column 3")
      end

      it "rejects `else` indented under `if` (different column)" do
        expect { parse("- if x\n  - else") }.to raise_error(Slang::ParseError, "branch `else` has no matching preceding branchable at line 2, column 5")
      end

      it "captures children of the branchable separately" do
        doc = parse("- if x\n  p Yes\n- else\n  p No")
        code = doc.nodes.first.as(AST::Code)
        yes_p = code.children.first.as(AST::Element)
        no_p = code.branches.first.children.first.as(AST::Element)
        expect(literal_parts(yes_p.children.first.as(AST::Text).parts)).to eq([{"Yes", false}])
        expect(literal_parts(no_p.children.first.as(AST::Text).parts)).to eq([{"No", false}])
      end

      it "supports nested branchables independently" do
        doc = parse("- if x\n  - if y\n    p Inner Yes\n  - else\n    p Inner No\n- else\n  p Outer No")
        outer_if = doc.nodes.first.as(AST::Code)
        inner_if = outer_if.children.first.as(AST::Code)
        inner_yes = inner_if.children.first.as(AST::Element).children.first.as(AST::Text)
        inner_no = inner_if.branches.first.children.first.as(AST::Element).children.first.as(AST::Text)
        outer_no = outer_if.branches.first.children.first.as(AST::Element).children.first.as(AST::Text)
        expect(literal_parts(inner_yes.parts)).to eq([{"Inner Yes", false}])
        expect(literal_parts(inner_no.parts)).to eq([{"Inner No", false}])
        expect(literal_parts(outer_no.parts)).to eq([{"Outer No", false}])
      end
    end
  end
end
