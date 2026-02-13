require "ameba"

module Ameba::Rule::Ktistec
  # Prevents focused spec markers in specs.
  #
  # Focused spec markers (`fdescribe`, `fcontext`, `fit`) cause only
  # the focused specs to run, masking failures elsewhere. They should
  # not be committed.
  #
  class NoFocusedSpecs < Base
    properties do
      description "Focused spec markers should not be committed."
      enabled true
    end

    FOCUSED_METHODS = %w[fdescribe fcontext fit]

    MSG = <<-MSG
      Avoid committing focused spec markers.

      Focused specs prevent the full test suite from running:
        fdescribe  ->  describe
        fcontext   ->  context
        fit        ->  it
      MSG

    def test(source)
      return unless source.path.ends_with?("_spec.cr")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return if node.obj

      issue_for node, MSG if FOCUSED_METHODS.includes?(node.name)
    end
  end
end
