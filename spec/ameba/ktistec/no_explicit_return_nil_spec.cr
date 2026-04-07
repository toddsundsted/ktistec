require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_explicit_return_nil"

Spectator.describe Ameba::Rule::Ktistec::NoExplicitReturnNil do
  let(rule) { described_class.new }

  it "reports `return nil`" do
    source = Ameba::Source.new %(
      def foo
        return nil
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("return nil")
  end

  it "reports `return nil` with if guard" do
    source = Ameba::Source.new %(
      def foo(x)
        return nil if x.nil?
        x + 1
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("return nil")
  end

  it "reports `return nil` with unless guard" do
    source = Ameba::Source.new %(
      def foo(x)
        return nil unless x
        x + 1
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("return nil")
  end

  it "reports multiple `return nil` statements" do
    source = Ameba::Source.new %(
      def foo(x)
        return nil if x.nil?
        return nil if x.empty?
        x.first
      end
    )

    rule.test(source)
    expect(source.issues.size).to eq(2)
    expect(source.issues).to all(have_attributes(message: contain("return nil")))
  end

  it "allows bare `return`" do
    source = Ameba::Source.new %(
      def foo(x)
        return if x.nil?
        x + 1
      end
    )

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows `return` with a value" do
    source = Ameba::Source.new %(
      def foo(x)
        return x if x > 0
        -x
      end
    )

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
