require "ameba"

module Ameba::Rule::Ktistec
  # Prevents `eq(true)` and `eq(false)` in spec matchers.
  #
  # Spectator provides `be_true` and `be_false` matchers which are
  # more idiomatic and read more naturally.
  #
  # This is considered invalid:
  #
  # ```
  # expect(result).to eq(true)
  # expect(result).to eq(false)
  # ```
  #
  # And should be written as:
  #
  # ```
  # expect(result).to be_true
  # expect(result).to be_false
  # ```
  #
  class NoEqBooleanInSpecs < Base
    properties do
      description "Prefer `be_true`/`be_false` over `eq(true)`/`eq(false)`."
      enabled true
    end

    MSG_TRUE = <<-MSG
      Prefer `be_true` over `eq(true)`.

        eq(true)   ->  be_true
      MSG

    MSG_FALSE = <<-MSG
      Prefer `be_false` over `eq(false)`.

        eq(false)  ->  be_false
      MSG

    def test(source)
      return unless source.path.ends_with?("_spec.cr")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "eq"
      return unless node.args.size == 1

      arg = node.args.first
      if arg.is_a?(Crystal::BoolLiteral)
        issue_for node, arg.value ? MSG_TRUE : MSG_FALSE
      end
    end
  end
end
