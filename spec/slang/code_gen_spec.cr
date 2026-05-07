require "./spec_helper"

# helpers referenced from spec slang sources. macro-time `run` cannot
# see runtime variables, so spec slang must be string literals; these
# helpers stand in for whatever bindings a real template would have.

def evaluates_to_nil
  nil
end

def wrap_block(&block : -> String)
  "[#{block.call}]"
end

def wrap_block_with_arg(&block : Int32 -> String)
  "[#{block.call(42)}]"
end

def evaluates_to_amp
  "&world"
end

Spectator.describe Slang::CodeGen do
  describe "Element" do
    it "renders an empty tag" do
      expect(render_string("div")).to eq("<div></div>")
    end

    it "renders a self-closing tag" do
      expect(render_string("br")).to eq("<br>")
    end

    it "renders nested tags" do
      expect(render_string(<<-SLANG)).to eq("<div><p></p><ul><li></li></ul></div>")
        div
          p
          ul
            li
        SLANG
    end

    it "renders class shorthand" do
      expect(render_string("div.foo")).to eq("<div class=\"foo\"></div>")
    end

    it "renders multiple class shorthand" do
      expect(render_string("div.foo.bar.baz")).to eq("<div class=\"foo bar baz\"></div>")
    end

    it "renders id shorthand" do
      expect(render_string("div#main")).to eq("<div id=\"main\"></div>")
    end

    it "renders implicit div" do
      expect(render_string("#main")).to eq("<div id=\"main\"></div>")
    end

    it "renders implicit div" do
      expect(render_string(".foo")).to eq("<div class=\"foo\"></div>")
    end

    it "renders trailing text" do
      expect(render_string("span Hello")).to eq("<span>Hello</span>")
    end

    it "renders attribute" do
      expect(render_string("input type=\"text\"")).to eq("<input type=\"text\">")
    end

    it "renders multiple attributes" do
      expect(render_string("input type=\"text\" name=\"foo\" placeholder=\"bar\"")).to eq(
        "<input type=\"text\" name=\"foo\" placeholder=\"bar\">",
      )
    end

    it "preserves spaces inside a quoted attribute value" do
      expect(render_string(%(span attr="hello  world"))).to eq(%(<span attr="hello  world"></span>))
    end

    it "preserves `=` inside a quoted attribute value" do
      expect(render_string(%(h1 id="asdf=" Hello))).to eq(%(<h1 id="asdf=">Hello</h1>))
    end

    it "accepts complex expressions as attribute values" do
      expect(render_string(%(span class=("f" + "oo")))).to eq(%(<span class="foo"></span>))
    end

    it "renders wrapped attributes" do
      expect(render_string("input(type=\"text\" name=\"foo\")")).to eq(
        "<input type=\"text\" name=\"foo\">",
      )
    end

    it "renders wrapped attributes" do
      expect(render_string("input[type=\"text\" name=\"foo\"]")).to eq(
        "<input type=\"text\" name=\"foo\">",
      )
    end

    it "renders wrapped attributes" do
      expect(render_string("input{type=\"text\" name=\"foo\"}")).to eq(
        "<input type=\"text\" name=\"foo\">",
      )
    end

    it "HTML-escapes literal attribute values" do
      expect(render_string("input value=\"A & B\"")).to eq("<input value=\"A &amp; B\">")
    end

    it "HTML-escapes dynamic attribute values" do
      expect(render_string(<<-SLANG)).to eq(%(<span attr="&quot;Hello&quot; &amp; world"></span>))
        - val = %("Hello" & world)
        span attr=val
        SLANG
    end

    it "re-escapes already-encoded entities in dynamic attribute values" do
      expect(render_string(<<-SLANG)).to eq(%(<span attr="&amp;quot;Hello&amp;quot; &amp; world"></span>))
        - val = "&quot;Hello&quot; & world"
        span attr=val
        SLANG
    end

    it "renders attribute names containing a colon" do
      expect(render_string(%(svg xmlns:xlink="http://www.w3.org/1999/xlink"))).to eq(
        %(<svg xmlns:xlink="http://www.w3.org/1999/xlink"></svg>),
      )
    end
  end

  describe "URL attributes" do
    it "emits a SafeURI value as the attribute" do
      expect(render_string(%(a href=Ktistec::SafeURI.assert_safe("/x?a=1&b=2")))).to eq(
        %(<a href="/x?a=1&amp;b=2"></a>),
      )
    end

    it "omits the attribute when the value is nil" do
      expect(render_string("a href=evaluates_to_nil")).to eq(%(<a></a>))
    end
  end

  describe "Event-handler attributes" do
    # `Slang::Runtime.emit_event_attr` is intentionally undefined.
    # `button onclick=expr` (any expression form) fails to compile.

    it "emits an author-typed string literal verbatim" do
      expect(render_string(%(button onclick="alert(1)" Click))).to eq(
        %(<button onclick="alert(1)">Click</button>),
      )
    end

    it "HTML-escapes the literal value" do
      expect(render_string(%(button onclick="x &amp; y" Click))).to eq(
        %(<button onclick="x &amp;amp; y">Click</button>),
      )
    end
  end

  describe "Boolean attributes" do
    it "emits the name for true" do
      expect(render_string("input checked=true")).to eq("<input checked>")
    end

    it "omits the attribute for false" do
      expect(render_string("input checked=false")).to eq("<input>")
    end

    it "emits an empty value for nil" do
      expect(render_string("input value=evaluates_to_nil")).to eq(%(<input value="">))
    end

    # but, splat values that are nil are skipped entirely

    it "skips nil splat values (no `name=\"\"`)" do
      expect(render_string(<<-SLANG)).to eq(%(<input type="text">))
        - attrs = {"type" => "text", "value" => nil}
        input *attrs
        SLANG
    end

    it "stringifies values" do
      expect(render_string("input value=\"checked\"")).to eq("<input value=\"checked\">")
    end
  end

  describe "Class merging" do
    it "merges shorthand and literal attributes" do
      expect(render_string("div.foo class=\"bar\"")).to eq("<div class=\"foo bar\"></div>")
    end

    it "merges shorthand and dynamic attributes" do
      expect(render_string("div.foo class=evaluates_to_hello")).to eq("<div class=\"foo hello\"></div>")
    end

    it "merges shorthand with a entry from a splat hash" do
      expect(render_string(<<-SLANG)).to eq(%(<span class="foo bar" id="baz"></span>))
        - attrs = {"class" => "bar", "id" => "baz"}
        span.foo *attrs
        SLANG
    end

    it "omits class entirely when shorthand is absent and dynamic value is empty" do
      expect(render_string("div class=\"\"")).to eq("<div></div>")
    end

    it "drops an empty literal class when merging with shorthand" do
      expect(render_string("span.quuz class=\"\"")).to eq(%(<span class="quuz"></span>))
    end

    it "omits class entirely when dynamic value is nil" do
      expect(render_string("div class=evaluates_to_nil")).to eq("<div></div>")
    end
  end

  describe "Attribute order" do
    it "emits id before class for shorthand `#id.class`" do
      expect(render_string("span#a.b")).to eq(%(<span id="a" class="b"></span>))
    end

    it "emits id before class for shorthand `.class#id`" do
      expect(render_string("span.b#a")).to eq(%(<span id="a" class="b"></span>))
    end

    it "emits id before class for explicit `class=` then `id=`" do
      expect(render_string(%(span class="b" id="a"))).to eq(%(<span id="a" class="b"></span>))
    end

    it "emits id before class for shorthand id + explicit class" do
      expect(render_string(%(span#a class="b"))).to eq(%(<span id="a" class="b"></span>))
    end

    it "emits id before class for shorthand class + explicit id" do
      expect(render_string(%(span.b id="a"))).to eq(%(<span id="a" class="b"></span>))
    end
  end

  describe "Output" do
    it "renders escaped output" do
      expect(render_string(%(= "<a>"))).to eq("&lt;a&gt;")
    end

    it "renders raw output" do
      expect(render_string(%(== "<a>"))).to eq("<a>")
    end

    it "renders an evaluated expression" do
      expect(render_string("= 1 + 2")).to eq("3")
    end

    it "renders output following an element" do
      expect(render_string("span = 1 + 2")).to eq("<span>3</span>")
    end

    it "renders inline output with no space before `=` (escaped)" do
      expect(render_string(%(span= "<a>"))).to eq("<span>&lt;a&gt;</span>")
    end

    it "renders inline output with no space before `==` (raw)" do
      expect(render_string(%(span== "<a>"))).to eq("<span><a></span>")
    end

    it "renders inline output with no space before `==` after class shorthand" do
      expect(render_string(%(span.foo== "x"))).to eq(%(<span class="foo">x</span>))
    end

    it "renders nil as empty string" do
      expect(render_string("= nil")).to eq("")
    end

    context "given a SafeHTML value" do
      let(safe) { Ktistec::SafeHTML.assert_safe("<a>") }

      it "emits it raw via `=`" do
        expect(render_string("= safe")).to eq("<a>")
      end

      it "emits it raw via `==`" do
        expect(render_string("== safe")).to eq("<a>")
      end
    end
  end

  describe "Block helpers (== with do)" do
    it "passes child HTML to a helper block" do
      expect(render_string(<<-SLANG)).to eq("[<p>inner</p>]")
        == wrap_block do
          p inner
        SLANG
    end

    it "passes child HTML to a helper block that takes an argument" do
      expect(render_string(<<-SLANG)).to eq("[<p>42</p>]")
        == wrap_block_with_arg do |n|
          p = n
        SLANG
    end

    it "renders a helper block attached inline to a parent element" do
      expect(render_string(<<-SLANG)).to eq("<div>[<p>42</p>]</div>")
        div == wrap_block_with_arg do |n|
          p = n
        SLANG
    end
  end

  describe "Control" do
    it "renders if/else branches" do
      expect(render_string(<<-SLANG)).to eq("<p>Yes</p>")
        - if 1 == 1
          p Yes
        - else
          p No
        SLANG
    end

    it "renders case/when branches" do
      expect(render_string(<<-SLANG)).to eq("<p>Two</p>")
        - case 2
        - when 1
          p One
        - when 2
          p Two
        - else
          p Other
        SLANG
    end

    it "renders begin/rescue branches" do
      expect(render_string(<<-SLANG)).to eq("<p>Caught</p>")
        - begin
          - raise "bad"
        - rescue
          p Caught
        SLANG
    end

    it "renders an iterator" do
      expect(render_string(<<-SLANG)).to eq("<p>1</p><p>2</p><p>3</p>")
        - [1, 2, 3].each do |n|
          p = n
        SLANG
    end

    it "renders an iterator attached inline to a parent element" do
      expect(render_string(<<-SLANG)).to eq("<div><p>1</p><p>2</p><p>3</p></div>")
        div - [1, 2, 3].each do |n|
          p = n
        SLANG
    end

    it "renders an assignment" do
      expect(render_string(<<-SLANG)).to eq("<p>hello</p>")
        - x = "hello"
        p = x
        SLANG
    end
  end

  describe "Text" do
    it "renders a pipe text block" do
      expect(render_string(<<-SLANG)).to eq("line one\nline two")
        | line one
          line two
        SLANG
    end

    it "renders a quote text block with trailing space" do
      expect(render_string(<<-SLANG)).to eq("line one\nline two ")
        ' line one
          line two
        SLANG
    end

    it "drops the trailing blank line that precedes a dedent in a `|` block" do
      expect(render_string(<<-SLANG)).to eq("text<div></div>")
        | text

        div
        SLANG
    end

    it "preserves relative indent for deeper-indented lines in a `|` block" do
      expect(render_string(<<-SLANG)).to eq("<a><b>A\nB\n  C</b></a>")
        a
          b
            | A
              B
                C
        SLANG
    end

    it "renders raw HTML" do
      expect(render_string("<strong>bold</strong>")).to eq("<strong>bold</strong>")
    end

    it "renders raw HTML" do
      expect(render_string("|\n  <br>")).to eq("<br>")
    end

    it "renders raw HTML as a child of a tag" do
      expect(render_string("div\n  <ah>")).to eq("<div><ah></div>")
    end

    it "interpolates inside text" do
      expect(render_string(<<-SLANG)).to eq("<span>Hello, World!</span>")
        - name = "World"
        span Hello, \#{name}!
        SLANG
    end

    it "renders non-ASCII (UTF-8) text" do
      expect(render_string(<<-SLANG)).to eq("<head><title>Привет, Мир</title></head><body><p>Предложение</p></body>")
        head
          title Привет, Мир
        body
          p Предложение
        SLANG
    end

    it "does not escape source `\"` in trailing text" do
      expect(render_string(%(div "ah"))).to eq(%(<div>"ah"</div>))
    end

    it "does not escape source `&` in trailing text" do
      expect(render_string("div hello & world")).to eq("<div>hello & world</div>")
    end

    it "does not escape source `<` and `>` in trailing text" do
      expect(render_string("div x<a>y")).to eq("<div>x<a>y</div>")
    end

    it "escapes interpolation results in trailing text" do
      expect(render_string(%(div hello \#{evaluates_to_amp}))).to eq("<div>hello &amp;world</div>")
    end

    it "scans `%(...)`, `%[...]`, `%{...}`, `%<...>` Crystal string literals inside `\#{}` interpolation" do
      expect(render_string(<<-SLANG)).to eq(%(<span>hello world</span><span>&quot;hello world&quot;</span><span>&quot;hello world&quot;</span><span>&quot;hello world&quot;</span>))
        span \#{%(hello \#{"world"})}
        span \#{%["hello \#{"world"}"]}
        span \#{%{"hello \#{"world"}"}}
        span \#{%<"hello \#{"world"}">}
        SLANG
    end

    it "treats `\\\\` as a literal backslash in trailing text" do
      expect(render_string(%(span use "\\\\%"))).to eq(%(<span>use "\\%"</span>))
    end

    it "treats `\\\\` as a literal backslash in `|` text blocks" do
      expect(render_string(<<-SLANG)).to eq(%(use "\\%"))
        | use "\\\\%"
        SLANG
    end

    it "treats `=EXPR` after interpolation as inline output" do
      expect(render_string(<<-SLANG)).to eq("<code>x5</code>")
        - var = "x"
        code \#{var}=5
        SLANG
    end

    it "treats `-EXPR` after interpolation as inline code" do
      expect(render_string(<<-SLANG)).to eq("<span>my</span>")
        - prefix = "my"
        span \#{prefix}-5
        SLANG
    end

    it "preserves literal `=` after interpolation when escaped with `\\=`" do
      expect(render_string(<<-SLANG)).to eq("<code>x=5</code>")
        - var = "x"
        code \#{var}\\=5
        SLANG
    end

    it "preserves literal `-` after interpolation when escaped with `\\-`" do
      expect(render_string(<<-SLANG)).to eq("<span>my-5</span>")
        - prefix = "my"
        span \#{prefix}\\-5
        SLANG
    end
  end

  describe "Inline tags" do
    it "renders an inline tag" do
      expect(render_string("li.first: a Hello")).to eq(
        "<li class=\"first\"><a>Hello</a></li>",
      )
    end

    it "renders inline tags" do
      expect(render_string("li: a: span text")).to eq(
        "<li><a><span>text</span></a></li>",
      )
    end

    it "treats `: ==` as inline output of the parent (no implicit div)" do
      expect(render_string(%(span: == "x"))).to eq("<span>x</span>")
    end

    it "treats `: =` as inline output of the parent (no implicit div)" do
      expect(render_string(%(span: = "x"))).to eq("<span>x</span>")
    end
  end

  describe "Whitespace controls" do
    it "emits a leading space" do
      expect(render_string(<<-SLANG)).to eq("<div><span>1</span> <span>2</span></div>")
        div
          span 1
          span< 2
        SLANG
    end

    it "emits a trailing space" do
      expect(render_string(<<-SLANG)).to eq("<div><span>1</span> <span>2</span></div>")
        div
          span> 1
          span 2
        SLANG
    end

    it "emits both leading and trailing space" do
      expect(render_string(<<-SLANG)).to eq("<div><span>1</span> <span>2</span> <span>3</span></div>")
        div
          span 1
          span<> 2
          span 3
        SLANG
    end

    it "prepends a space" do
      expect(render_string(%(=< "hello"))).to eq(" hello")
    end

    it "appends a space" do
      expect(render_string(%(=> "hello"))).to eq("hello ")
    end
  end

  describe "Comments" do
    it "emits nothing for hidden comment" do
      expect(render_string(<<-SLANG)).to eq("<span>visible</span>")
        / hidden
        span visible
        SLANG
    end

    it "emits a visible comment" do
      expect(render_string("/! hello world")).to eq("<!--hello world-->")
    end

    it "emits an interpolated value" do
      expect(render_string(<<-SLANG)).to eq("<!--note: a -&#45;&gt; b-->")
        - val = "a --> b"
        /! note: \#{val}
        SLANG
    end
  end

  describe "Doctype" do
    it "emits an HTML5 doctype" do
      expect(render_string("doctype html")).to eq("<!DOCTYPE html>")
    end

    it "emits a doctype with a multi-token value" do
      expect(render_string(%(doctype html PUBLIC "-//W3C//DTD"))).to eq(%(<!DOCTYPE html PUBLIC "-//W3C//DTD">))
    end
  end

  describe "Rawstuff" do
    it "wraps a javascript: block in <script>" do
      expect(render_string(<<-SLANG)).to eq("<script>var x = 1;</script>")
        javascript:
          var x = 1;
        SLANG
    end

    it "wraps a css: block in <style>" do
      expect(render_string(<<-SLANG)).to eq("<style>body { margin: 0; }</style>")
        css:
          body { margin: 0; }
        SLANG
    end

    it "joins multiple content lines with a single `\\n`" do
      expect(render_string(<<-SLANG)).to eq(%(<script>var x = 1;\nvar y = 2;</script>))
        javascript:
          var x = 1;
          var y = 2;
        SLANG
    end

    it "preserves relative indent for deeper-indented lines" do
      expect(render_string(<<-SLANG)).to eq(%(<script>var x = {\n  a: 1\n};</script>))
        javascript:
          var x = {
            a: 1
          };
        SLANG
    end

    it "drops the trailing blank line that precedes a dedent" do
      expect(render_string(<<-SLANG)).to eq(%(<script>var x = 1;</script><div></div>))
        javascript:
          var x = 1;

        div
        SLANG
    end

    it "evaluates a crystal: block" do
      expect(render_string(<<-SLANG)).to eq("<p>42</p>")
        crystal:
          x = 42
        p = x
        SLANG
    end
  end

  describe "Single evaluation" do
    let(counter) { Counter.new }

    it "evaluates a class= expression once" do
      render_string(%(div class=counter.call("hello")))
      expect(counter.count).to eq(1)
    end

    it "evaluates an attribute expression once" do
      render_string(%(input value=counter.call("v")))
      expect(counter.count).to eq(1)
    end

    it "evaluates an attribute expression once" do
      render_string("input checked=counter.call(true)")
      expect(counter.count).to eq(1)
    end

    it "evaluates an attribute expression once" do
      render_string("input checked=counter.call(false)")
      expect(counter.count).to eq(1)
    end

    it "evaluates a splat expression once" do
      render_string(%(input *counter.call({"data-x" => "y"})))
      expect(counter.count).to eq(1)
    end

    it "evaluates an output expression once" do
      render_string(%(= counter.call("hello")))
      expect(counter.count).to eq(1)
    end

    it "evaluates an interpolated expression once" do
      render_string(%(span Hello, \#{counter.call("world")}!))
      expect(counter.count).to eq(1)
    end

    it "evaluates an interpolated expression once" do
      render_string(%(span Hello \#{counter.call("<world>")}))
      expect(counter.count).to eq(1)
    end

    it "evaluates two source occurrences twice" do
      render_string(%(div class=counter.call("a") class=counter.call("b")))
      expect(counter.count).to eq(2)
    end

    it "evaluates a combined element with class assignment and splat once each" do
      render_string(%(div.literal class=counter.call("dyn") *counter.call({"data-x" => "y"})))
      expect(counter.count).to eq(2)
    end
  end

  describe "Source attribution" do
    it "wraps generated Crystal in #<loc:push>/#<loc:pop>" do
      crystal = Slang.process_string("p Hello", "src/foo.slang", "io")
      expect(crystal.includes?(%(#<loc:"src/foo.slang",1,1>))).to be_true
      expect(crystal.starts_with?("#<loc:push>")).to be_true
      expect(crystal.ends_with?("#<loc:pop>\n")).to be_true
    end

    it "omits directives when filename is nil" do
      crystal = Slang.process_string("p Hello", nil, "io")
      expect(crystal.includes?("#<loc:")).to be_false
    end

    it "omits directives when filename is empty" do
      crystal = Slang.process_string("p Hello", "", "io")
      expect(crystal.includes?("#<loc:")).to be_false
    end

    it "emits per-fragment loc directives at expression sites" do
      crystal = Slang.process_string("= some_expr", "src/foo.slang", "io")
      directives = crystal.scan(/#<loc:"src\/foo\.slang",\d+,\d+>/).map(&.[0])
      expect(directives).to eq([
        %(#<loc:"src/foo.slang",1,1>),
        %(#<loc:"src/foo.slang",1,3>),
      ])
    end
  end
end
