require "spectator"

require "../../src/slang"

Spectator.describe Slang::CrystalScanner do
  describe ".scan" do
    context "with no terminator in source" do
      it "returns end of source for empty source" do
        expect(Slang::CrystalScanner.scan("", 0, " ")).to eq(0)
      end

      it "returns end of source for plain text" do
        expect(Slang::CrystalScanner.scan("foo", 0, " ")).to eq(3)
      end

      it "returns end of source when pos is at the end" do
        expect(Slang::CrystalScanner.scan("foo", 3, " ")).to eq(3)
      end

      it "clamps pos past end of source" do
        expect(Slang::CrystalScanner.scan("foo", 99, " ")).to eq(3)
      end

      it "clamps negative pos to zero" do
        expect(Slang::CrystalScanner.scan(" foo", -1, " ")).to eq(0)
      end

      it "raises ArgumentError on non-ASCII terminators" do
        expect { Slang::CrystalScanner.scan("foo", 0, "日") }.to raise_error(ArgumentError)
      end
    end

    context "with simple terminators" do
      it "stops at the first terminator at depth zero" do
        expect(Slang::CrystalScanner.scan("foo bar", 0, " ")).to eq(3)
      end

      it "matches any byte from a multi-character terminator string" do
        expect(Slang::CrystalScanner.scan("foo:bar", 0, " :<>\n")).to eq(3)
      end

      it "stops at newline when newline is a terminator" do
        expect(Slang::CrystalScanner.scan("foo\nbar", 0, "\n")).to eq(3)
      end

      it "does not stop at newline when newline is not a terminator" do
        expect(Slang::CrystalScanner.scan("foo\nbar", 0, " ")).to eq(7)
      end

      it "starts scanning from pos" do
        expect(Slang::CrystalScanner.scan("xx foo bar", 3, " ")).to eq(6)
      end
    end

    context "with bracket nesting" do
      it "ignores terminators inside parentheses" do
        expect(Slang::CrystalScanner.scan("a(b c)d e", 0, " ")).to eq(7)
      end

      it "ignores terminators inside square brackets" do
        expect(Slang::CrystalScanner.scan("a[b c]d e", 0, " ")).to eq(7)
      end

      it "ignores terminators inside curly braces" do
        expect(Slang::CrystalScanner.scan("a{b c}d e", 0, " ")).to eq(7)
      end

      it "ignores terminators inside nested brackets of the same type" do
        expect(Slang::CrystalScanner.scan("(a (b) c) x", 0, " ")).to eq(9)
      end

      it "ignores terminators inside nested brackets of mixed types" do
        expect(Slang::CrystalScanner.scan("(a [b {c}] d) x", 0, " ")).to eq(13)
      end

      it "ignores a closing bracket terminator while inside an opener" do
        expect(Slang::CrystalScanner.scan("(a) b)", 0, ")")).to eq(5)
      end

      it "treats a closing bracket as terminator at depth zero" do
        expect(Slang::CrystalScanner.scan("foo bar)", 0, ")")).to eq(7)
      end

      it "scans wrapper contents from past the opener" do
        expect(Slang::CrystalScanner.scan("(foo)", 1, ")")).to eq(4)
      end

      it "scans nested wrapper contents from past the opener" do
        expect(Slang::CrystalScanner.scan("((a))", 1, ")")).to eq(4)
      end
    end

    context "with double-quoted strings" do
      it "handles empty strings" do
        expect(Slang::CrystalScanner.scan(%("" foo), 0, " ")).to eq(2)
      end

      it "ignores terminators inside strings" do
        expect(Slang::CrystalScanner.scan(%("a b c" foo), 0, " ")).to eq(7)
      end

      it "handles escaped quotes inside strings" do
        expect(Slang::CrystalScanner.scan(%("a \\" b" foo), 0, " ")).to eq(8)
      end

      it "handles escaped backslash inside strings" do
        expect(Slang::CrystalScanner.scan(%("a\\\\" foo), 0, " ")).to eq(5)
      end

      it "ignores brackets inside strings" do
        expect(Slang::CrystalScanner.scan(%("(a)" foo), 0, " ")).to eq(5)
      end

      it "handles string interpolation" do
        expect(Slang::CrystalScanner.scan(%("hello \#{world}" foo), 0, " ")).to eq(16)
      end

      it "ignores terminators inside interpolations" do
        expect(Slang::CrystalScanner.scan(%("a \#{b c} d" foo), 0, " ")).to eq(12)
      end

      it "handles nested strings inside interpolations" do
        expect(Slang::CrystalScanner.scan(%("a \#{"x y"} b" foo), 0, " ")).to eq(14)
      end

      it "handles escaped # in strings" do
        expect(Slang::CrystalScanner.scan(%("\\\#{x}" foo), 0, " ")).to eq(7)
      end

      it "treats unterminated strings as consumed to EOF" do
        expect(Slang::CrystalScanner.scan(%("unterminated), 0, " ")).to eq(13)
      end
    end

    context "with char literals" do
      it "ignores terminators inside char literals" do
        expect(Slang::CrystalScanner.scan("'a' foo", 0, " ")).to eq(3)
      end

      it "handles escape sequences in char literals" do
        expect(Slang::CrystalScanner.scan("'\\n' foo", 0, " ")).to eq(4)
      end

      it "handles escaped single quotes in char literals" do
        expect(Slang::CrystalScanner.scan("'\\'' foo", 0, " ")).to eq(4)
      end

      it "handles escaped backslash in char literals" do
        expect(Slang::CrystalScanner.scan("'\\\\' foo", 0, " ")).to eq(4)
      end

      it "treats unterminated char literals as consumed to EOF" do
        expect(Slang::CrystalScanner.scan("'a", 0, " ")).to eq(2)
      end
    end

    context "with percent literals" do
      it "handles bare percent literal with parentheses" do
        expect(Slang::CrystalScanner.scan("%(a b c) foo", 0, " ")).to eq(8)
      end

      it "handles bare percent literal with brackets" do
        expect(Slang::CrystalScanner.scan("%[a b c] foo", 0, " ")).to eq(8)
      end

      it "handles bare percent literal with braces" do
        expect(Slang::CrystalScanner.scan("%{a b c} foo", 0, " ")).to eq(8)
      end

      it "handles bare percent literal with angle brackets" do
        expect(Slang::CrystalScanner.scan("%<a b c> foo", 0, " ")).to eq(8)
      end

      it "handles typed percent literal %w()" do
        expect(Slang::CrystalScanner.scan("%w(a b c) foo", 0, " ")).to eq(9)
      end

      it "handles typed percent literal %i[]" do
        expect(Slang::CrystalScanner.scan("%i[a b] foo", 0, " ")).to eq(7)
      end

      it "handles typed percent literal %Q{}" do
        expect(Slang::CrystalScanner.scan("%Q{a b} foo", 0, " ")).to eq(7)
      end

      it "handles nested same-type delimiters in percent literals" do
        expect(Slang::CrystalScanner.scan("%w(a (b) c) foo", 0, " ")).to eq(11)
      end

      it "handles typed percent literal with pipes" do
        expect(Slang::CrystalScanner.scan("%w|a b| foo", 0, " ")).to eq(7)
      end

      it "handles bare percent literal with pipes" do
        expect(Slang::CrystalScanner.scan("%|a b| foo", 0, " ")).to eq(6)
      end

      it "treats pipes as non-nesting" do
        expect(Slang::CrystalScanner.scan("%|a| b|", 0, " ")).to eq(4)
      end

      it "treats bare % as a non-special byte when not followed by a known opener" do
        expect(Slang::CrystalScanner.scan("a%b c", 0, " ")).to eq(3)
      end

      it "treats % followed by an unrecognized character as non-special" do
        expect(Slang::CrystalScanner.scan("a%z c", 0, " ")).to eq(3)
      end

      it "honors backslash-escaped delimiters in percent literals" do
        expect(Slang::CrystalScanner.scan("%(a\\)b) foo", 0, " ")).to eq(7)
      end

      it "honors interpolation in percent literals" do
        expect(Slang::CrystalScanner.scan("%Q(a \#{b}c) foo", 0, " ")).to eq(11)
      end

      it "shields percent-literal closer inside interpolation" do
        expect(Slang::CrystalScanner.scan("%Q(\#{f(\"a)\")}) foo", 0, " ")).to eq(14)
      end
    end

    context "with line comments" do
      it "stops at the newline that terminates the comment" do
        expect(Slang::CrystalScanner.scan("foo # bar baz\nqux", 0, "\n")).to eq(13)
      end

      it "consumes the comment to EOF when no terminating newline is present" do
        expect(Slang::CrystalScanner.scan("foo # bar", 0, "\n")).to eq(9)
      end

      it "ignores brackets inside comments" do
        expect(Slang::CrystalScanner.scan("foo # (bar\nqux", 0, "\n")).to eq(10)
      end

      it "ignores quotes inside comments" do
        expect(Slang::CrystalScanner.scan(%(foo # "bar\nqux), 0, "\n")).to eq(10)
      end
    end

    context "with UTF-8 in expressions" do
      it "scans past multi-byte characters in plain text" do
        expect(Slang::CrystalScanner.scan("日本語 foo", 0, " ")).to eq(9)
      end

      it "scans past multi-byte characters inside strings" do
        expect(Slang::CrystalScanner.scan(%("日本語" foo), 0, " ")).to eq(11)
      end
    end

    context "given realistic Slang/Crystal expressions" do
      it "handles a method call with arguments" do
        expect(Slang::CrystalScanner.scan("form_for(env)\n", 0, "\n")).to eq(13)
      end

      it "handles a block-passing form to end-of-line" do
        src = "form_for(env) do |form|\n"
        expect(Slang::CrystalScanner.scan(src, 0, "\n")).to eq(23)
      end

      it "handles attribute value with interpolation" do
        src = %(class="post post-\#{kind}" type="x")
        expect(Slang::CrystalScanner.scan(src, 6, " :<>\n")).to eq(25)
      end

      it "handles a hash argument with string keys" do
        src = %({"href" => url, "rel" => "noopener"} foo)
        expect(Slang::CrystalScanner.scan(src, 0, " ")).to eq(36)
      end

      it "handles a wrapped attribute list" do
        src = %{(type="text" name="x" value=foo)}
        expect(Slang::CrystalScanner.scan(src, 1, ")")).to eq(31)
      end

      it "ignores a colon inside brackets" do
        expect(Slang::CrystalScanner.scan("(a:b) c", 0, " :<>\n")).to eq(5)
      end
    end
  end
end
