require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_else_nil"

Spectator.describe Ameba::Rule::Ktistec::NoElseNil do
  let(rule) { described_class.new }

  it "reports `else nil` in if" do
    source = Ameba::Source.new %(
      def foo(x)
        if x > 0
          x * 2
        else
          nil
        end
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("else nil")
  end

  it "reports `else nil` in unless" do
    source = Ameba::Source.new %(
      def foo(x)
        unless x.nil?
          x * 2
        else
          nil
        end
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("else nil")
  end

  it "reports multiple `else nil` clauses" do
    source = Ameba::Source.new %(
      def foo(x, y)
        a = if x > 0
          x * 2
        else
          nil
        end
        b = unless y > 0
          y * 2
        else
          nil
        end
        {a, b}
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(2)
    expect(source.issues).to all(have_attributes(message: contain("else nil")))
  end

  it "allows ternary with nil else" do
    source = Ameba::Source.new %(
      def foo(x)
        x > 0 ? x * 2 : nil
      end
    )

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows if/elsif/else" do
    source = Ameba::Source.new %(
      def foo(x)
        if x > 0
          x * 2
        elsif x < 0
          x * -1
        else
          0
        end
      end
    )

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
