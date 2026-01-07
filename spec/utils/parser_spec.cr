require "../../src/utils/parser"

require "../spec_helper/base"

Spectator.describe Ktistec::Node do
  subject { described_class.new("(node)", 0) }

  describe "#clone" do
    it "clones the node" do
      clone = subject.clone
      expect(clone).not_to be(subject)
    end
  end
end

Spectator.describe Ktistec::PrefixOperator do
  subject { described_class.new("(prefix operator)", 0) }

  describe "#nud" do
    it "returns a prefix operator" do
      parser = Ktistec::Parser.new("123")
      expect(subject.nud(parser)).to be_a(described_class)
    end

    it "consumes the expression to the right" do
      parser = Ktistec::Parser.new("foo")
      expect { subject.nud(parser) }.to change { subject.right?.try(&.id) }.to("foo")
    end

    it "raises an error if there is no expression to the right" do
      parser = Ktistec::Parser.new("   ")
      expect { subject.nud(parser) }.to raise_error(Ktistec::Parser::SyntaxError, /expecting expression/)
    end
  end
end

Spectator.describe Ktistec::InfixOperator do
  let(left) { Ktistec::Node.new("(left)", 0) }

  subject { described_class.new("(infix operator)", 0) }

  describe "#led" do
    it "returns an infix operator" do
      parser = Ktistec::Parser.new("123")
      expect(subject.led(parser, left)).to be_a(described_class)
    end

    it "consumes the expression to the right" do
      parser = Ktistec::Parser.new("foo")
      expect { subject.led(parser, left) }.to change { subject.right?.try(&.id) }.to("foo")
    end

    it "raises an error if there is no expression to the right" do
      parser = Ktistec::Parser.new("   ")
      expect { subject.led(parser, left) }.to raise_error(Ktistec::Parser::SyntaxError, /expecting expression/)
    end
  end
end

Spectator.describe Ktistec::RuleDefinition::Pattern do
  describe "#parse" do
    it "allows keywords as arguments" do
      parser = Ktistec::Parser.new(%q|condition Constant, end|).tap(&.current)
      expect(described_class.new("condition").parse(parser).arguments.map(&.token.value)).to eq(["end"])
    end

    it "allows expressions as arguments" do
      parser = Ktistec::Parser.new(%q|condition Constant, foo.id|).tap(&.current)
      expect(described_class.new("condition").parse(parser).arguments.map(&.token.value)).to eq(["."])
    end

    it "allows keywords in option keys" do
      parser = Ktistec::Parser.new(%q|condition Constant, end: "end"|).tap(&.current)
      expect(described_class.new("condition").parse(parser).options.transform_values(&.token.value)).to eq({"end" => "end"})
    end

    it "allows expressions in option values" do
      parser = Ktistec::Parser.new(%q|condition Constant, foo: foo.id|).tap(&.current)
      expect(described_class.new("condition").parse(parser).options.transform_values(&.token.value)).to eq({"foo" => "."})
    end

    it "raises on error if option key is invalid" do
      parser = Ktistec::Parser.new(%q|condition Constant, 123: 123|).tap(&.current)
      expect { described_class.new("condition").parse(parser) }.to raise_error(Ktistec::Parser::SyntaxError, /key must be an identifier/)
    end

    it "raises an error if definition includes multiple constants" do
      parser = Ktistec::Parser.new(%q|condition Foo, Bar|).tap(&.current)
      expect { described_class.new("condition").parse(parser) }.to raise_error(Ktistec::Parser::SyntaxError, /multiple constants are not permitted/)
    end

    it "raises an error if definition does not include a constant" do
      parser = Ktistec::Parser.new(%q|condition foo, bar|).tap(&.current)
      expect { described_class.new("condition").parse(parser) }.to raise_error(Ktistec::Parser::SyntaxError, /missing a constant/)
    end
  end

  context "given a pattern" do
    let(parser) { Ktistec::Parser.new(%q|condition Constant, 123, foo, bar, one: "1", two: 2.0 next|).tap(&.current) }
    subject! { described_class.new("condition").parse(parser) }

    it "returns a pattern" do
      is_expected.to be_a(described_class)
    end

    it "parses the constant" do
      expect(subject.constant.token.value).to eq("Constant")
    end

    it "parses the arguments" do
      expect(subject.arguments.map(&.token.value)).to eq([123, "foo", "bar"])
    end

    it "parses the options" do
      expect(subject.options.transform_values(&.token.value)).to eq({"one" => "1", "two" => 2.0})
    end

    it "positions the parser on the next token" do
      expect(parser.current.id).to eq("next")
    end
  end
end

Spectator.describe Ktistec::RuleDefinition do
  subject { described_class.new("rule", 0) }

  describe "#std" do
    it "returns a rule" do
      parser = Ktistec::Parser.new(%q|rule "name" end|).tap(&.current)
      expect(subject.std(parser)).to be_a(described_class)
    end

    it "parses the name" do
      parser = Ktistec::Parser.new(%q|rule "name" end|).tap(&.current)
      expect { subject.std(parser) }.to change { subject.name? }.to("name")
    end

    it "parses the trace keyword" do
      parser = Ktistec::Parser.new(%q|rule "name" trace end|).tap(&.current)
      expect { subject.std(parser) }.to change { subject.trace }.to(true)
    end

    it "parses the patterns" do
      parser = Ktistec::Parser.new(%q|rule "name" condition One condition Two end|).tap(&.current)
      expect { subject.std(parser) }.to change { subject.patterns.size }.to(2)
    end

    it "raises an error if name is not a literal string" do
      parser = Ktistec::Parser.new(%q|rule 123 end|).tap(&.current)
      expect { subject.std(parser) }.to raise_error(Ktistec::Parser::SyntaxError, /name must be a literal string/)
    end

    it "raises an error if end is missing" do
      parser = Ktistec::Parser.new(%q|rule "name"|).tap(&.current)
      expect { subject.std(parser) }.to raise_error(Ktistec::Parser::SyntaxError, /missing token: end/)
    end
  end

  describe "#clone" do
    it "deep copies patterns" do
      clone = subject.clone
      expect(clone.patterns).not_to be(subject.patterns)
    end
  end
end

Spectator.describe Ktistec::Parser do
  describe "#current" do
    it "returns a node" do
      parser = described_class.new("")
      expect(parser.current).to be_a(Ktistec::Node)
    end

    it "is a constant" do
      parser = described_class.new("Constant")
      expect(parser.current).to be_a(Ktistec::Constant)
    end

    it "is an identifier" do
      parser = described_class.new("identifier")
      expect(parser.current).to be_a(Ktistec::Identifier)
    end

    it "is an operator" do
      parser = described_class.new(".")
      expect { parser.current }.to be_a(Ktistec::Operator)
    end

    it "is a rule definition" do
      parser = described_class.new("rule")
      expect(parser.current).to be_a(Ktistec::RuleDefinition)
    end

    it "is a keyword" do
      parser = described_class.new("end")
      expect(parser.current).to be_a(Ktistec::Keyword)
    end

    it "raises an error when string is unterminated" do
      parser = described_class.new(%q|"|)
      expect { parser.current }.to raise_error(Ktistec::Parser::SyntaxError, /unterminated string/)
    end

    it "raises an error when operator is invalid" do
      parser = described_class.new("∙")
      expect { parser.current }.to raise_error(Ktistec::Parser::SyntaxError, /invalid operator/)
    end
  end

  describe "#advance" do
    it "raises an error if specified id does not match the current node's id" do
      parser = described_class.new("").tap(&.current)
      expect { parser.advance("foo") }.to raise_error(Ktistec::Parser::SyntaxError, /missing token: foo/)
    end
  end

  describe "#expression" do
    it "is end of input" do
      parser = described_class.new(%q||)
      expect(parser.expression.token.eoi?).to be_true
    end

    context "given a prefix operator" do
      it "parses the expression" do
        expression = described_class.new(%q|not x|).expression
        expect({expression.class, expression.id}).to eq({Ktistec::PrefixOperator, "not"})
        right = expression.as(Ktistec::PrefixOperator).right
        expect({right.class, right.id}).to eq({Ktistec::Identifier, "x"})
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|not x|).tap(&.expression)
        expect(parser.current.token.eoi?).to be_true
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|not x y|).tap(&.expression)
        expect(parser.current.id).to eq("y")
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|not x,|).tap(&.expression)
        expect(parser.current.id).to eq(",")
      end

      it "raises an error if there is no expression to the right" do
        parser = described_class.new(%q|not|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /expecting expression/)
      end

      it "raises an error if there is no expression to the right" do
        parser = described_class.new(%q|not,|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /unexpected token: \,/)
      end
    end

    context "given an infix operator" do
      it "parses the expression" do
        expression = described_class.new(%q|a.b|).expression
        expect({expression.class, expression.id}).to eq({Ktistec::InfixOperator, "."})
        left = expression.as(Ktistec::InfixOperator).left
        expect({left.class, left.id}).to eq({Ktistec::Identifier, "a"})
        right = expression.as(Ktistec::InfixOperator).right
        expect({right.class, right.id}).to eq({Ktistec::Identifier, "b"})
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|a.b|).tap(&.expression)
        expect(parser.current.token.eoi?).to be_true
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|a.b x|).tap(&.expression)
        expect(parser.current.id).to eq("x")
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|a.b,|).tap(&.expression)
        expect(parser.current.id).to eq(",")
      end

      it "raises an error if there is no expression to the right" do
        parser = described_class.new(%q|a.|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /expecting expression/)
      end

      it "raises an error if there is no expression to the right" do
        parser = described_class.new(%q|a.,|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /unexpected token: \,/)
      end

      it "raises an error if there is no expression to the left" do
        parser = described_class.new(%q|.b|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /unexpected token: \./)
      end
    end

    context "given a function operator" do
      it "parses the expression" do
        expression = described_class.new(%q|within(x, 1, 2, 3)|).expression
        expect({expression.class, expression.id}).to eq({Ktistec::FunctionOperator, "("})
        left = expression.as(Ktistec::FunctionOperator).left
        expect({left.class, left.id}).to eq({Ktistec::Identifier, "within"})
        right = expression.as(Ktistec::FunctionOperator).right
        expect(right.size).to eq(4)
        expect({right[0].class, right[0].id}).to eq({Ktistec::Identifier, "x"})
        expect({right[1].class, right[1].token.as_i}).to eq({Ktistec::Literal, 1})
        expect({right[2].class, right[2].token.as_i}).to eq({Ktistec::Literal, 2})
        expect({right[3].class, right[3].token.as_i}).to eq({Ktistec::Literal, 3})
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|within()|).tap(&.expression)
        expect(parser.current.token.eoi?).to be_true
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|within() x|).tap(&.expression)
        expect(parser.current.id).to eq("x")
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|within(),|).tap(&.expression)
        expect(parser.current.id).to eq(",")
      end

      it "raises an error if there is no closing parenthesis" do
        parser = described_class.new(%q|within(|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /missing token: \)/)
      end

      it "raises an error if there is no closing parenthesis" do
        parser = described_class.new(%q|within(,|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /unexpected token: \,/)
      end

      it "raises an error if there is no expression to the left" do
        parser = described_class.new(%q|()|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /unexpected token: \(/)
      end

      it "raises an error if the expression to the left is not an identifier" do
        parser = described_class.new(%q|5()|)
        expect { parser.expression }.to raise_error(Ktistec::Parser::SyntaxError, /expecting identifier/)
      end
    end
  end

  describe "#statement" do
    it "is end of input" do
      parser = described_class.new(%q||)
      expect(parser.expression.token.eoi?).to be_true
    end

    context "given a rule definition" do
      it "parses the statement" do
        statement = described_class.new(%q|rule "name" end|).statement
        expect({statement.class, statement.id}).to eq({Ktistec::RuleDefinition, "rule"})
      end

      it "positions the parser on the next token" do
        parser = described_class.new(%q|rule "name" end next|).tap(&.statement)
        expect(parser.current.id).to eq("next")
      end

      it "raises an error if end is missing" do
        parser = described_class.new(%q|rule "name"|)
        expect { parser.statement }.to raise_error(Ktistec::Parser::SyntaxError, /missing token: end/)
      end
    end
  end

  describe "#statements" do
    it "returns no statements" do
      parser = described_class.new("")
      expect(parser.statements).to be_empty
    end

    it "returns two rules" do
      parser = described_class.new(%q|rule "one" end rule "two" end|)
      expect(parser.statements.size).to eq(2)
    end
  end
end
