require "ameba"

module Ameba::Rule::Ktistec
  # Prevents redundant `else nil` clauses in if/unless expressions.
  #
  # In Crystal, an if/unless expression without an else branch already
  # returns `nil` when the condition is not taken, making `else nil`
  # redundant.
  #
  class NoElseNil < Base
    properties do
      description "Prefer omitting `else nil` from if/unless expressions."
      enabled true
    end

    MSG = <<-MSG
      Prefer omitting `else nil` from if/unless expressions.

      An if/unless expression already returns nil when the condition
      is not taken:
        if cond; value; else; nil; end  ->  if cond; value; end
      MSG

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::If | Crystal::Unless)
      return if node.location == node.cond.location
      issue_for node.else, MSG if node.else.is_a?(Crystal::NilLiteral)
    end
  end
end
