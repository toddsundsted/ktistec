require "ameba"

module Ameba::Rule::Ktistec
  # Prevents explicit `return nil` statements.
  #
  # In Crystal, a bare `return` already returns `nil`, making the
  # explicit `nil` redundant. Use `return` instead of `return nil`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # return nil if condition
  # return nil unless condition
  # return nil
  # ```
  #
  # And should be written as:
  #
  # ```
  # return if condition
  # return unless condition
  # return
  # ```
  #
  class NoExplicitReturnNil < Base
    properties do
      description "Prefer `return` over `return nil`."
      enabled true
    end

    MSG = <<-MSG
      Prefer `return` over `return nil`.

      A bare `return` already returns nil:
        return nil  ->  return
      MSG

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Def)
      visitor = ReturnNilVisitor.new(node)
      visitor.return_nil_nodes.each do |return_node|
        issue_for return_node, MSG
      end
    end

    private class ReturnNilVisitor < Crystal::Visitor
      getter return_nil_nodes = [] of Crystal::Return

      def initialize(node : Crystal::Def)
        node.accept(self)
      end

      def visit(node : Crystal::Return)
        @return_nil_nodes << node if node.exp.is_a?(Crystal::NilLiteral)
        true
      end

      def visit(node : Crystal::ASTNode)
        true
      end
    end
  end
end
