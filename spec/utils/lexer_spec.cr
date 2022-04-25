require "../../src/utils/lexer"

require "../spec_helper/base"

Spectator.describe Ktistec::Lexer do
  describe "#advance" do
    it "returns a token" do
      lexer = described_class.new("")
      expect(lexer.advance).to be_a(Ktistec::Token)
    end

    it "is end of input" do
      lexer = described_class.new("")
      expect(lexer.advance.eoi?).to be_true
    end

    it "is a literal string" do
      lexer = described_class.new(%q|"string"|)
      expect(lexer.advance.string?).to be_true
      expect(lexer.token.as_s).to eq("string")
    end

    it "is a literal string" do
      lexer = described_class.new(%q|"\"\s\t\r\i\n\g\""|)
      expect(lexer.advance.string?).to be_true
      expect(lexer.token.as_s).to eq(%q|"string"|)
    end

    it "is an error if the string is unterminated" do
      lexer = described_class.new(%q|"|)
      expect(lexer.advance.error?).to be_true
      expect(lexer.token.as_s).to eq("unterminated string")
    end

    it "is a literal int" do
      lexer = described_class.new("123")
      expect(lexer.advance.int?).to be_true
      expect(lexer.token.as_i).to eq(123)
    end

    it "is a literal float" do
      lexer = described_class.new("123.4")
      expect(lexer.advance.float?).to be_true
      expect(lexer.token.as_f).to eq(123.4)
    end

    it "is a constant" do
      lexer = described_class.new("Constant")
      expect(lexer.advance.constant?).to be_true
      expect(lexer.token.as_s).to eq("Constant")
    end

    it "is an identifier" do
      lexer = described_class.new("identifier")
      expect(lexer.advance.identifier?).to be_true
      expect(lexer.token.as_s).to eq("identifier")
    end

    it "is an operator" do
      lexer = described_class.new("→")
      expect(lexer.advance.operator?).to be_true
      expect(lexer.token.as_s).to eq("→")
    end

    it "ignores whitespace" do
      lexer = described_class.new("  identifier  ")
      expect(lexer.advance.identifier?).to be_true
      expect(lexer.token.as_s).to eq("identifier")
    end

    it "ignores comments" do
      lexer = described_class.new("# comment")
      expect(lexer.advance.eoi?).to be_true
    end

    def analyze_fully(lexer)
      results = [] of {Symbol, String | Int64 | Float64}
      until lexer.advance.eoi?
        case lexer.token.type
        in Ktistec::Token::Type::EOI
          # nop
        in Ktistec::Token::Type::Error
          # nop
        in Ktistec::Token::Type::String
          results << {:string, lexer.token.as_s}
        in Ktistec::Token::Type::Int
          results << {:int, lexer.token.as_i}
        in Ktistec::Token::Type::Float
          results << {:float, lexer.token.as_f}
        in Ktistec::Token::Type::Constant
          results << {:constant, lexer.token.as_s}
        in Ktistec::Token::Type::Identifier
          results << {:identifier, lexer.token.as_s}
        in Ktistec::Token::Type::Operator
          results << {:operator, lexer.token.as_s}
        end
      end
      results
    end

    it "handles successive tokens" do
      lexer = described_class.new(%q|"s" 123|)
      expect(analyze_fully(lexer)).to eq([{:string, "s"}, {:int, 123}])
    end

    it "handles successive tokens" do
      lexer = described_class.new("a/B")
      expect(analyze_fully(lexer)).to eq([{:identifier, "a"}, {:operator, "/"}, {:constant, "B"}])
    end

    it "ignores whitespace" do
      lexer = described_class.new(" foo: bar ")
      expect(analyze_fully(lexer)).to eq([{:identifier, "foo"}, {:operator, ":"}, {:identifier, "bar"}])
    end

    it "ignores comments" do
      lexer = described_class.new(%q|12.3 # comment|)
      expect(analyze_fully(lexer)).to eq([{:float, 12.3}])
    end
  end
end
