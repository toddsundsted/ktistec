# Slang Specification

Behavioral specification for Slang as used in Ktistec. Describes
the input grammar, HTML output semantics, and macro contract.
Lexer, parser, and codegen internals are implementation details
and not part of the contract.

### Terminology

- **template** — a `.slang` source file.
- **rendered HTML** — the bytes the generated Crystal writes to its
  buffer at runtime. Distinct from "generated Crystal" (the source
  emitted at compile time).
- **inline tag** / **inline element** — an element introduced by `:`
  on the same line as another element. Structurally an element, not
  a text node.
- **rawstuff block** — the colon-suffixed special tags
  (`javascript:`, `css:`, `crystal:`) plus the bare `script` and
  `style` elements. Children are not parsed as Slang.
- **void element** — an HTML tag from a fixed list (§5.1.7) that
  emits no closing tag. Slang emits these as `<tag>` (HTML style),
  not `<tag/>` (XHTML style).

---

## 1. Overview

Slang is a Slim-derived template language that compiles **at compile
time** to Crystal source code. A `.slang` file is read at compile time,
parsed, and translated to Crystal that, when compiled into the
program, emits HTML at runtime.

```
.slang source ──[compile time]──> Crystal source ──[compile time]──> machine code ──[runtime]──> HTML bytes
```

Slang has no runtime parser. The Slang code paths in the binary are
purely the *result* of compile-time translation.

---

## 2. Macro Contract

Slang exposes three things to consumers: one compile-time macro and
two helper functions, defined in `src/slang/macros.cr` and
`src/slang.cr`. The behavioral test suite at `spec/slang/code_gen_spec.cr`
exercises this surface directly.

### 2.1 `Slang.embed(filename, io_name)`

Compile-time macro. Parameters:

- `filename` — string literal. Path to a `.slang` file relative to the
  process's compile-time working directory.
- `io_name` — identifier. Names the local binding the generated code
  will write HTML bytes to.

Effect: the file at `filename` is read, parsed, and translated to
Crystal source code which is inlined at the macro call site. The
inlined code references a local binding named `io_name` and emits
HTML by appending strings to it.

The local binding must be in scope at the call site and must be an
`IO`. The generated code uses three sink operations: `io << literal`
(string append), `::HTML.escape(s, io)` (escaping write), and
`(expr).to_s(io)` (stringification write). All three require `IO`.
In Ktistec, `io_name` is always `content_io`, a local `IO::Memory`
(in the layout-aware render path) or a `String::Builder` (which
extends `IO`) yielded from a `String.build` block (layout-less
render path).

The template sees all locals in scope at the call site by Crystal's
ordinary lexical scoping rules. There is no separate "context" or
"binding" mechanism beyond Crystal's lexical scope.

### 2.2 `Slang.process_file(filename, buffer_name = "__slang__")`

Pure function. String → String. Reads `.slang` source from
`filename`, parses, and returns the equivalent Crystal source as a
string. Used in tooling; not in the runtime path.

### 2.3 `Slang.process_string(slang_source, filename = ..., buffer_name = "__slang__")`

Same as `process_file` but takes the source as a string. The
`filename` argument is used only for source-location directives in
the output (see §6).

### 2.4 Constants

- `Slang::DEFAULT_BUFFER_NAME = "__slang__"`

### 2.5 Determinism and Source Attribution

1. **Determinism.** The compile-time translation is pure: identical
   `.slang` input + identical buffer-name argument produces identical
   Crystal source bytes. Every run, every machine.
2. **Source attribution.** Crystal compile errors in user-written
   expressions inside templates point at the `.slang` file, not at a
   generated buffer. See §6 for the directive contract.

The `io_name` + `<<` calling convention is part of the public API
surface (§2.1). Internal sink mechanics — `String.build` boundaries,
sub-buffer naming, etc. — are not.

---

## 3. Lexical Layer

### 3.1 Source Encoding

UTF-8 throughout. Non-ASCII bytes pass through to output unmodified.

### 3.2 Line Termination

`\n` (LF) terminates a line. `\r\n` (CRLF) is also accepted; a bare
`\r` not followed by `\n` is a lex error.

### 3.3 Indentation

Indentation determines block nesting. Spaces only — a tab in
indentation position is a lex error.

The indent unit is fluid: children must be at a strictly greater
column than their parent. There is no fixed two-spaces-per-level
requirement at the language level; the parser walks up by column
comparison. Convention in Ktistec templates is 2 spaces per level.

### 3.4 Blank Lines

Lines containing only whitespace are skipped.

### 3.5 Escape Sequences

Inside text content, `\` is an escape introducer. The recognized
slang escapes are:

- `\\` — literal `\` (escape the escape character itself). Source
  `\\%` produces the two-character output `\%`.
- `\#` — literal `#`, suppressing string interpolation that would
  otherwise begin with `#{`.
- `\=` — literal `=`, used after interpolation to suppress the
  lexer's inline-output detection (§3.6).
- `\-` — literal `-`, used after interpolation to suppress the
  lexer's inline-code detection (§3.6).

In each case the backslash is consumed and the following byte is
written to the text content as a literal. To produce a literal `\`
followed by one of `#`, `=`, or `-`, write `\\\#`, `\\\=`, or
`\\\-` respectively.

Backslash sequences not in this list (`\n`, `\t`, `\"`, etc.) are
not interpreted by slang: the backslash is emitted literally to
the rendered output. (Implementation note: the bytes pass through
the generated Crystal string literal in a form that round-trips
to the original source bytes, so source `\n` renders as the
two-character sequence `\n`, not a newline.)

### 3.6 String Interpolation

Inside text content (not attribute values), `#{expr}` interpolates the
Crystal expression `expr`. Nesting works: an interpolated expression
may contain string literals (`"..."`, `'...'`) and percent-literals
(`%w(...)`, `%(...)`, etc.). Brackets/braces/parens are balanced
inside `#{...}`.

After an interpolation closes (the `}` of `#{...}`), a literal `=`
immediately following triggers output-mode lexing (the `=` rebinds
as Crystal output of the same element); a literal `-` triggers
code-mode lexing (the `-` rebinds as a Crystal statement, which
emits nothing). Write `\=` / `\-` to insert a literal `=` / `-`
after interpolation. The transition fires only in element trailing
text, and only when the trigger byte is immediately adjacent to the
closing `}` — intervening whitespace suppresses it.

---

## 4. Block Structure

### 4.1 Lines as Nodes

Each non-blank line of a `.slang` document corresponds to one node
(or, in special cases, a continuation of a previous node — see §5.4
text blocks and §5.5 rawstuff blocks).

### 4.2 Indentation-Driven Nesting

A node's parent is the most recent node with a strictly smaller
column number. Equivalently: the node is a child of the line it is
indented under.

```slang
div                              # column 1, parent: document
  p Hello                        # column 3, parent: div
  ul                             # column 3, parent: div
    li First                     # column 5, parent: ul
    li Second                    # column 5, parent: ul
```

### 4.3 Inline Composition (`:`)

The colon `:` after an element introduces an *inline* child element on
the same line:

```slang
li.first: a href="/a" A link
```

This is equivalent to:

```slang
li.first
  a href="/a" A link
```

Multiple inline tags chain:

```slang
li: a: span text
```

Inline elements are tracked with an `inline` flag distinct from
column-based nesting. The chain may continue with text after the
final inline element on the same line.

After `:`, the inline construct may be:

- An element (with optional shorthand, attributes, splat, etc.).
- An output (`= EXPR` or `== EXPR`) — emits the value as inline
  content of the parent (`span: == "x"` -> `<span>x</span>`).
- A code statement (`- STMT`) — embeds Crystal code at this
  position; emits no output of its own.

There is no implicit-`div` fallback when the next token is not an
element. `: ==` and `: =` and `: -` introduce output / output /
code respectively, attached as the next inline child of the
parent. (This differs from line-start, where `.` and `#` imply
`div` per §5.1.4. Inline-after-`:` does not extend that rule
to `=` / `==` / `-`.)

For self-closing parents (§5.1.7), the inline construct still
emits — it appears immediately after the `>` of the void element
(rendered as a sibling by the browser, since the void element
opens no scope):

```slang
br: a href="/x" Click   →  <br><a href="/x">Click</a>
br: == "x"              →  <br>x
```

A leading `:` at the start of a line — no preceding element — is a
lex error.

### 4.4 Block Continuations

Some constructs span multiple lines without each line being a separate
node:

- **Text blocks** (`|` and `'`) — continued by indented text lines
  (§5.4.2-3).
- **Rawstuff blocks** (`javascript:`, `css:`, `crystal:`) — continued
  by indented verbatim source lines (§5.5).

In both cases, the dedent rule is: a line at a column ≤ the block's
content column ends the block.

---

## 5. Constructs

### 5.1 Element

Syntax:

```
NAME[.CLASS|#ID|<|>]* [ATTRIBUTES] [: INLINE_CHILD] [TEXT]
```

The simplest case is a tag name alone:

```slang
div
```

renders as `<div></div>`.

#### 5.1.1 Tag Name

A run of `[A-Za-z0-9_-]` characters, optionally including `:` not
followed by an attribute-wrapper opener (`{`, `[`, `(`, ` `). This
permits namespaced names like `xmlns:xlink`.

If the tag name is `doctype`, the line is a doctype declaration
instead of an element (see §5.7).

If the tag name is one of `javascript:`, `css:`, `crystal:`, the line
opens a rawstuff block (see §5.5).

#### 5.1.2 Id Shorthand

`#NAME` after a tag name (or as the first token, implying `div`) sets
the element's id:

```slang
div#main       →  <div id="main"></div>
#main          →  <div id="main"></div>
```

Multiple `#NAME` shorthands on a single element — `#a#b` — is a parse
error.

#### 5.1.3 Class Shorthand

`.NAME` after a tag name (or as the first token, implying `div`)
appends `NAME` to the element's class attribute. `NAME` is a
literal run of `[A-Za-z0-9_-]`. Multiple `.NAME` clauses
accumulate:

```slang
div.foo.bar    →  <div class="foo bar"></div>
.foo           →  <div class="foo"></div>
```

Class shorthand values are emitted as literal strings. There is no
interpolation syntax in the shorthand position — runtime class
values use either a `class=EXPR` attribute or the splat's `class`
key (§5.1.6).

#### 5.1.4 Implicit Div

If a line begins with `.` or `#`, the tag is implicitly `div`. See
above.

#### 5.1.5 Attributes

Attributes may appear after the tag name + shorthand. Two delimiter
styles:

**Space-delimited** (default):

```slang
input type="text" name="x"
```

The first whitespace after the element terminates the
shorthand-and-controls sequence and begins attribute scanning. Each
attribute is `NAME=VALUE`. VALUE is a Crystal expression terminated
by whitespace (or by `>`/`<` whitespace controls, or by end-of-line).
`:` is **not** a value terminator -- production templates use `::`
for Crystal namespace constants (e.g.,
`href=Ktistec::ViewHelper.path`) and `:foo` for symbol literals
inside expressions. Inline-child `:` is still recognized after the
value scan stops at whitespace; writing `attr=value:inline` (no
space) is undefined.

**Wrapper-delimited** — `(...)`, `[...]`, `{...}`:

```slang
input(type="text" name="x")
input[type="text" name="x"]
input{type="text" name="x"}
```

Inside a wrapper, attribute values may contain whitespace. The outer
wrapper closer must be the same kind as the opener: `(` pairs with
`)`, `[` with `]`, `{` with `}`. A mismatched closer is a lex error.
Internal bracket nesting inside Crystal expressions in attribute
values is unaffected by this rule (the Crystal scanner handles
expression-internal balance).

**Attribute value escaping:**

Attribute values are Crystal expressions, not string literals. They
are evaluated at runtime, converted to string via `.to_s`, and
HTML-escaped using the canonical escape function (see §5.9). So:

```slang
span attr="Hello & world"     →  <span attr="Hello &amp; world"></span>
span attr=val                 →  <span attr="<runtime to_s of val, escaped>"></span>
```

There is no `attr==value` syntax for raw (un-escaped) attribute
values.

**Attribute names:** `[A-Za-z0-9_-]` plus `:` (for namespaces like
`xmlns:xlink`). Other characters in attribute-name position are
not part of the contract.

**Valueless attributes:** attribute names without `=VALUE` are not
part of the contract; behavior is undefined.

**Duplicate non-class attributes:** each `name="value"` emits in
source order, which produces multiple attributes of the same name
in the output (browsers use the first). Observable but not part of
the contract beyond "no template depends on a specific resolution
rule."

**Boolean attributes:**

If the value evaluates to:

- `true` — emit attribute name only: `<input checked>`
- `false` — omit attribute entirely.
- anything else — emit `name="value"` (including `nil`, which
  stringifies to `""` and emits `name=""` — *not* omit; only
  `false` omits). Production templates depend on this for form
  fields like `value=object.name` where `name` may be nil but
  the form field must still be present in the rendered HTML.

```slang
input type="checkbox" checked=true            →  <input type="checkbox" checked>
input type="checkbox" checked=false           →  <input type="checkbox">
input type="checkbox" checked="checked"       →  <input type="checkbox" checked="checked">
input type="text" value=nil                   →  <input type="text" value="">
```

Splat values (§5.8) follow a different nil rule: nil splat values
are *skipped*. The unwrapped-attribute "nil → empty string" rule
above applies only to `name=expr` source forms.

**Emission order:** the attributes on an element are emitted in this
order, regardless of source order:

1. `id` — from shorthand `#NAME`, or (if no shorthand) the first
   explicit `id="..."` attribute.
2. `class` — the merged value from §5.1.6.
3. Other attributes, in source order.
4. Splat key/value pairs (excluding `class`, which is already merged).

Both `<span#a.b>` and `<span.b#a>` therefore emit
`<span id="a" class="b">`. Production tests pin this order via byte
comparison.

#### 5.1.6 Class Merging

Class values can come from three sources:

1. Shorthand `.NAME` on the tag.
2. Explicit `class="..."` attribute (one or more).
3. The `class` key of a splat (see §5.8).

All three sources are merged into a single `class="..."` attribute
in the output, space-separated, in this order:

1. Shorthand classes (in source order).
2. Explicit `class=...` attributes (in source order).
3. Splat `class` value (whatever the runtime hash yields).

Each value is HTML-escaped before insertion (§5.9). Empty strings
and `nil` values are skipped. If all three sources resolve to
empty/nil, the entire `class` attribute is omitted (no `class=""`).

```slang
div.foo class="bar"            →  <div class="foo bar"></div>
div.foo class="bar" class=x    →  <div class="foo bar <runtime x>"></div>
div.foo *attrs                 →  <div class="foo <runtime attrs[\"class\"]>" ...></div>
```

#### 5.1.7 Self-Closing Tags

The tags `area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`,
`keygen`, `link`, `menuitem`, `meta`, `param`, `source`, `track`,
`wbr` emit no closing `</tag>`. Children attached via the inline
`:` chain or via an indented block are still rendered, immediately
after the `>` of the self-closing tag (effectively as siblings,
since the void element opens no scope):

```slang
br: a href="/x" Click   →  <br><a href="/x">Click</a>
```

This pattern appears in production templates (e.g.,
`partials/actor-panel.html.slang` uses `br: a href=...` to
introduce a handle link after a line break).

#### 5.1.8 Whitespace Controls

`<` and `>` after the tag name (or shorthand sequence) emit a literal
space adjacent to the element:

- `div<` — emit a space *before* `<div>`.
- `div>` — emit a space *after* `</div>`.
- `div<>` — emit spaces on both sides.

```slang
div
  span 1
  span<> 2
  span 3

→  <div><span>1</span> <span>2</span> <span>3</span></div>
```

These act on the immediate emit of the element; they don't propagate
to descendants.

#### 5.1.9 Inline Child via `:`

See §4.3.

#### 5.1.10 Trailing Text

After attributes (and optional `:`-introduced inline element), the
remainder of the line is treated as text content of the element (or
of the last inline element):

```slang
span Hello world      →  <span>Hello world</span>
span: a Hello         →  <span><a>Hello</a></span>
```

Source bytes in trailing text pass through verbatim — `"`, `&`, `<`,
`>`, and `'` are emitted as literals, not HTML-escaped (see §5.4.6).
Interpolation values (`#{expr}`) are HTML-escaped per §5.9. See §5.4
for the text node contract and §5.4.4 for the raw HTML pass-through.

### 5.2 Output (`=` and `==`)

Syntax:

```
= EXPR
== EXPR
```

`=` evaluates the Crystal expression `EXPR` at runtime and writes
the result to the buffer. `Ktistec::SafeHTML` values are emitted
raw; any other value has `.to_s` applied and is HTML-escaped
(§5.9). `==` writes the value's `.to_s` raw, no HTML-escape.

```slang
= 1 + 2                                  →  3
= "<a>"                                  →  &lt;a&gt;
= Ktistec::SafeHTML.assert_safe("<a>")   →  <a>
== "<a>"                                 →  <a>
```

If `EXPR` evaluates to `nil`, the buffer receives the empty string
(Crystal's `nil.to_s == ""`). There is no special "skip if nil"
path.

Output may follow an element or stand alone. When attached to an
element, the leading whitespace before `=` / `==` is optional --
`tag.class==EXPR` and `tag== EXPR` (no space) are equivalent to
`tag.class == EXPR` (production templates use the no-space form,
e.g. `span.link.item== Ktistec.settings.footer`). The element's
shorthand sequence ends as soon as the lexer encounters `=` / `==`
even without an intervening whitespace.

```slang
span = name                  →  <span><runtime escaped name></span>
span== name                  →  <span><runtime raw name></span>
= some_helper                →  <runtime escaped some_helper>
```

#### 5.2.1 Whitespace Controls

`=<` (equivalently `==<`) prepends a space to the value's output.
`=>` (equivalently `==>`) appends a space. The space is emitted as
a separate write to the buffer, not folded into the value's escape
or stringification.

#### 5.2.2 Output with Children (Block Helpers)

If `EXPR` is a Crystal expression that opens a block (e.g.,
`form_helper(env) do |form|`), indented children below form the
block body:

```slang
= form_for(env) do |form|
  input type="text" name="x"
```

The children render to a sub-buffer (`String.build`) which the
helper receives as its block. The helper's return value is then
written to the outer buffer following the rules of §5.2.

There is no Slang-level check that `EXPR` actually opens a block.
If the user writes `= some_method` with no block opener and indents
children below, the generated Crystal will fail to compile, with
the error attributed to the `.slang` file via the source-location
directives in §6.

Sub-buffer names are deterministic: identical input produces
identical generated Crystal across runs.

### 5.3 Control (`-` lines)

Syntax: `- CRYSTAL_STATEMENT`

A `-` line embeds Crystal source. Indented children form its body
(if the statement opens a block). The codegen emits the Crystal
verbatim, then renders children, then emits `end` if needed.

```slang
- if x > 0
  p Positive
- else
  p Non-positive
```

```slang
- [1, 2, 3].each do |n|
  p = n
```

#### 5.3.1 Branchable Statements

`if`, `case`, `begin` are *branchable* — subsequent `-` lines at the
same column may attach as branches.

#### 5.3.2 Branches

`else`, `elsif`, `when`, `in`, `rescue`, `ensure` attach to the most
recent branchable at the same column number. The branchable's `end`
is emitted only after all attached branches.

| Branchable | Allowed branches              |
|------------|-------------------------------|
| `if`       | `elsif`, `else`               |
| `case`     | `when`, `in`, `else`          |
| `begin`    | `rescue`, `ensure`, `else`    |

#### 5.3.3 Implicit `end`

`end` emission is **structural**, not text-aware. Slang does not
parse `EXPR` to detect whether it opens a block. The rule is:

- A `-` line emits `end` after its body if it has children **or**
  attached branches **and** is not itself a branch.
- A branch (`else`, `elsif`, `when`, `in`, `rescue`, `ensure`)
  never emits its own `end` — the `end` belongs to the parent
  branchable.
- A `-` line with no children, no branches, and no branchable role
  emits no `end`. This handles assignments and single statements:

```slang
- x = 5
- arr << "foo"
```

Branchable detection is by leading-keyword match on `EXPR`: `if `,
`case `, and `begin` (with optional whitespace) make a `-` line
branchable; `else`, `elsif `, `when `, `in `, `rescue`, `ensure`
make it a branch. Other Crystal block-opening forms (`unless`,
`while`, `until`, `for`, `def`, `class`, `module`, `do |...|`) are
**not recognized as branchable** — they may have children, in
which case `end` is emitted, but they cannot host attached
branches at the same column.

This means `- form_for(env) do |form|` followed by indented
children works (children + `end`), but `- if x` followed by an
attached `- else` at the same column works only because `if` is in
the branchable list. A `- unless x` followed by `- else` does not
attach.

#### 5.3.4 Inline Control

`-` may follow an element on the same line:

```slang
div - [1,2,3].each do |n|
  p = n
```

The control becomes a child of the element. The element's `</div>`
emits after the control's `end`.

### 5.4 Text

Text appears in four forms:

1. Trailing text on an element line (§5.1.10).
2. Text block (`|`) — multi-line verbatim text.
3. Text block with trailing space (`'`) — same as `|` but appends a
   single space.
4. Raw HTML (`<` at start of line) — treated as a TEXT token with
   HTML-escape disabled.

Inline elements (`:`) are structurally elements, not text — see
§4.3 and §5.1.9.

#### 5.4.1 Inline Trailing Text

Already covered in §5.1.10. HTML-escaped by default.

#### 5.4.2 Text Block (`|`)

```slang
| Line one.
  Line two.
    Line three.
```

The first line's leading `| ` is consumed; subsequent indented lines
continue the block. Each continuation is emitted with its
relative-to-block-start indentation preserved:

```
Line one.
Line two.
  Line three.
```

Newline rules:

- A `\n` separator is emitted *between* consecutive content lines,
  never *before* the first or *after* the last.
- When the opener has inline content (`| Hello`), the first
  continuation line is preceded by `\n` (separator from the
  opener's content).
- When the opener has no inline content (`|` then LF, content on
  next physical line), the first continuation line is emitted
  without a leading `\n`.
- Runs of blank lines inside the block collapse to a single `\n`
  separator.
- Trailing blank lines (between the last content line and the
  block's dedent or EOF) emit nothing.

Text in `|` blocks is **not** HTML-escaped.

The block's content column is anchored at the column immediately
after the `|` marker; subsequent lines at column ≥ that anchor
are part of the block.

#### 5.4.3 Text Block With Trailing Space (`'`)

Identical to `|` except an extra space is appended after the block:

```slang
' Line one.
  Line two.
```

Used to insert a separator after the text when the next sibling
should not be flush against it.

#### 5.4.4 Raw HTML

A line beginning with `<` is treated as raw HTML text — the entire
line is emitted as a TEXT token with `escaped=false`:

```slang
<div>verbatim html</div>      →  <div>verbatim html</div>
```

Used inside larger templates that want to drop in pre-formatted HTML
without nested Slang structure.

#### 5.4.5 Whitespace Controls

Text adjacent to elements with whitespace controls inherits a
prepend-space (`<`) or append-space (`>`) flag from the element.
There is no syntax for setting these on standalone text.

#### 5.4.6 Quoted Text

Text in attribute values is the only place double-quoted strings
have lexer significance:

```slang
input value="Hello world"
```

Source bytes in element trailing text are emitted as literals --
including `"`, `&`, `<`, `>`, and `'`. Only interpolation values
(`#{expr}`) are HTML-escaped:

```slang
span "Hello"        →  <span>"Hello"</span>
span hello & world  →  <span>hello & world</span>
span x<a>y          →  <span>x<a>y</span>
```

### 5.5 Rawstuff

Three special tag names trigger verbatim-content lexing:

- `javascript:` — emits a `<script>` element; children are verbatim
  JavaScript source.
- `css:` — emits a `<style>` element; children are verbatim CSS
  source.
- `crystal:` — emits no element; children are verbatim Crystal source
  embedded directly into the output.

```slang
javascript:
  var x = 1;
  console.log(x);
```

```slang
crystal:
  clazz = [:a, :b, :c].map(&.to_s).join(" ")
p class=clazz
```

The block's content column is the column where the first content line
begins. Lines at column ≥ content column continue the block; a line
at column < content column ends it.

Newline rules match `|` text blocks (§5.4.2): `\n` separator
between content lines, no leading `\n` after the open tag, no
trailing `\n` before the close tag, blank-line runs collapse to a
single separator, trailing blanks are dropped. So `javascript:`
followed by two indented lines `var x = 1;` and `console.log(x);`
emits `<script>var x = 1;\nconsole.log(x);</script>`, not
`<script>\nvar x = 1;\nconsole.log(x);\n</script>`.

Bare `script` and `style` elements (no colon suffix) also receive
raw-text treatment for their children:

```slang
script
  console.log("hi")    # children of script element are raw, not parsed as Slang
```

The colon-suffixed `javascript:` and `css:` differ from the bare
forms only in that they emit the `<script>` / `<style>` wrapper
automatically; bare `script` / `style` are ordinary element lines
that happen to receive raw-content handling for their children.

### 5.6 Comments

Two forms, distinguished by what follows the `/`:

#### 5.6.1 Hidden Comment (`/`)

```slang
/ this is a developer comment
```

Emits nothing. Hidden from the rendered output entirely.

#### 5.6.2 Visible HTML Comment (`/!`)

```slang
/! This is visible
```

Emits `<!--This is visible-->`. Children, if any, are rendered
inside the comment, followed by a single `\n` before the closing
`-->`:

```slang
/! Note
  span note body
```

Emits `<!--Note<span>note body</span>\n-->`. The trailing `\n`
appears only when at least one child is present.

### 5.7 Doctype (`doctype`)

Syntax: `doctype VALUE`

```slang
doctype html      →  <!DOCTYPE html>
doctype xml       →  <!DOCTYPE xml>
```

`VALUE` is the rest of the line, taken verbatim and inserted between
`<!DOCTYPE ` and `>`. There is no enumeration of "known" doctype
forms — whatever follows the keyword is used.

### 5.8 Splat (`*var`)

```slang
input *attrs
```

`*VAR` after an element references a Crystal value (typically a
`Hash`-like) at runtime. Each key/value pair becomes an attribute.
The `class` key, if present, is merged with shorthand classes (see
§5.1.6). Other keys are emitted after the named attributes and after
shorthand classes.

```slang
attrs = {"class" => "bar", "id" => "baz"}
span.foo *attrs        →  <span class="foo bar" id="baz"></span>
```

When all class sources are literal — shorthand only, no `class=expr`,
no splat with a dynamic `class` key — the merged value is emitted as
a single literal string. Class-merging runtime code is generated only
when at least one dynamic class source is present.

Splat values:

- **Keys.** Each key is converted to string via `.to_s` and used
  as the attribute name verbatim (no escaping). Symbol keys (e.g.,
  `{:href => "/x"}`) and string keys (`{"href" => "/x"}`) both
  work. Adversarial keys are not part of the contract.
- **Values.** Each value is converted to string via `.to_s` and
  HTML-escaped using §5.9 — same rule as for explicit attributes.
- **Boolean values.** `true` and `false` in splat values are
  treated identically to explicit attributes (§5.1.5):
  `true` emits the bare attribute name, `false` omits the
  attribute. Other values stringify and emit normally.
- **`nil` values.** Treated as "skip this attribute" (no name, no
  `name=""` emission).

### 5.9 HTML Escaping

The canonical escape function is **Crystal stdlib `HTML.escape`**.
It maps:

| Input | Output  |
|-------|---------|
| `&`   | `&amp;` |
| `<`   | `&lt;`  |
| `>`   | `&gt;`  |
| `"`   | `&quot;`|
| `'`   | `&#39;` |

All other characters pass through unchanged (UTF-8 preserved).
Text content and attribute values use the same function.

Where the spec says "HTML-escaped," it means: convert the value to
string via Crystal's `.to_s` (which is `""` for `nil`), then apply
the table above. This applies to:

- §5.1.5 attribute values (with the boolean special case for
  `true` / `false`).
- §5.1.6 class values (shorthand, explicit, splat).
- §5.2 `=` output for non-`Ktistec::SafeHTML` values (`SafeHTML`
  values are emitted raw).
- §5.4 interpolation values (`#{expr}`) inside trailing text and
  any text token whose `escape` flag is true. Source bytes in
  trailing text are **not** escaped -- see §5.4.6 and §5.1.10.
- §5.8 splat keys (no) and values (yes).

The `==` form (§5.2) and `|` text blocks (§5.4.2) bypass escaping
entirely. The output is whatever bytes the runtime expression /
verbatim text emits, with no transformation.

### 5.10 Single Evaluation

Every Crystal expression that appears in a `.slang` source file
evaluates **exactly once per render**, regardless of how many
fragment sites the codegen visits when emitting that construct.
This is a hard correctness contract, not a quality-of-implementation
note. User expressions may have side effects (counters, logging,
non-idempotent method calls) or be expensive; both cases require
single evaluation to behave correctly.

This applies to every site where a Crystal expression appears in
the source:

- §5.1.5 attribute values (`name=expr`).
- §5.1.6 class sources from `class=expr` and from splat.
- §5.2 output (`= expr`, `== expr`).
- §5.3 control lines (`- stmt`).
- §5.4 string interpolation (`#{expr}`) inside text content.
- §5.8 splat (`*expr`) — the splat expression itself evaluates
  once when iteration starts; iteration then operates on the
  fetched hash without re-evaluating.

The contract is phrased as "exactly once per render" — not "at
most once." A template that includes `= some_method` writes the
result to the buffer; `some_method` runs once. A template that
includes `class=some_method` both inspects the result (presence
check) and writes it (escape + emit); `some_method` still runs
once. A template that includes `class=some_method
class=some_method` (the same expression in two attributes) evaluates
`some_method` twice — once per source occurrence.

Inspect-then-emit constructs route the user expression through a
helper-call argument so Crystal evaluates it once before the call
and the helper inspects the captured result.

---

## 6. Source Location Directives

The generated Crystal source is annotated with `#<loc:...>`
directives that tell the Crystal compiler to attribute parse
and compile errors in the enclosed code to the original `.slang`
file at the right line and column.

- Each generated document begins with a single
  `#<loc:push>#<loc:"FILE",1,1>` line (push and file directive
  concatenated, terminated by `\n`) where `FILE` is the
  `filename` argument that came from `Slang.embed` /
  `process_file` / `process_string`.
- Each generated document ends with a single `#<loc:pop>` line.
- If `filename` is empty / nil, neither the push/pop nor any
  per-fragment directive is emitted.

Inside the push/pop, a per-fragment `#<loc:"FILE",L,C>` directive
appears immediately before every **Crystal-expression site** — every
place where user-written Crystal source appears in the generated
output. The sites are:

- Each attribute-value expression (the right-hand side of
  `name=expr`, §5.1.5).
- Each splat expression (the operand of `*expr`, §5.8).
- Each output expression (the operand of `=` / `==`, §5.2).
- Each code line (the body of a `-` line, §5.3).
- Each interpolation expression (the body of `#{expr}` inside
  text, §5.4).
- Each block-helper body opener (the line that starts a `do`-block
  for an output-with-children, §5.2.2).

Per-fragment directives are **not** emitted before pure literal
byte sequences (tag opens, attribute names, escaped text, raw
HTML), because literals cannot generate Crystal compile errors.
The line and column in each directive are taken from the original
source position.

```crystal
#<loc:push>#<loc:"src/views/foo.html.slang",1,1>
content_io << "<div"
content_io << " class=\""
#<loc:"src/views/foo.html.slang",2,11>
content_io << ::HTML.escape((some_helper(env)).to_s)
content_io << "\""
content_io << ">"
#<loc:pop>
```

Without these directives, compile errors in user expressions
point at the generated Crystal source string, which is
unactionable.

The directives consume only generated-source bytes — Crystal's
parser strips them after using them for source attribution, so
they have no effect on the compiled binary's size or runtime.

---

## 7. Errors

### 7.1 Lex Errors

Lex errors surface as `Slang::LexError`, with `message`, `line`, and
`column` accessors. The `to_s` form is `<message> at line L,
column C`. Conditions include:

- bare `\r` (no following `\n`)
- tab in indentation
- unrecognized character at line start
- mismatched attribute wrapper closer

### 7.2 Parse Errors

Parse errors surface as `Slang::ParseError`, with the same shape as
`LexError`. Conditions include:

- a token in a position the parser's outer loop does not accept
- multiple `#id` shorthands on a single element
- a branch keyword (`else`, `elsif`, ...) with no matching preceding
  branchable

### 7.3 Compile Errors in User Code

Any syntactic or semantic problem in user-written Crystal expressions
(attribute values, output expressions, control statements, code
blocks) surfaces as a Crystal compile error, with location attributed
to the `.slang` source via the directives in §6.

Slang does not attempt to validate Crystal syntax at parse time; the
Crystal compiler is the validator.

### 7.4 Stability of Diagnostics

Diagnostic messages and the set of conditions that produce errors
are **not a compatibility surface**. Templates in the Ktistec
corpus do not contain malformed input. Error messages may be
reworded, and the lex-vs-parse classification of a given malformed
input may shift between versions.

The contract is: well-formed templates produce the same HTML
output. The diagnostic surface for malformed templates is open.

---

## 8. Out of Scope

The following are **not** part of the contract:

- The lexer's token taxonomy or token API.
- The parser's AST shape.
- The generated Crystal's variable-name conventions.
- The generated Crystal's exact byte layout.
- The internal sub-buffer mechanism for capturing block-helper
  return values.
