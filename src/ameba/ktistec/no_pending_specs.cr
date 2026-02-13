require "ameba"

module Ameba::Rule::Ktistec
  # Prevents pending spec markers in specs.
  #
  # Pending spec markers (`pending`, `xdescribe`, `xcontext`, `xit`)
  # should not be committed. Either fix the spec or remove it.
  #
  class NoPendingSpecs < Base
    properties do
      description "Pending spec markers should not be committed."
      enabled true
    end

    PENDING_METHODS = %w[pending xdescribe xcontext xit]

    MSG = <<-MSG
      Avoid committing pending spec markers.

      Either fix the spec or remove it entirely:
        xdescribe  ->  describe
        xcontext   ->  context
        xit        ->  it
        pending    ->  it (or remove)
      MSG

    def test(source)
      return unless source.path.ends_with?("_spec.cr")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return if node.obj

      issue_for node, MSG if PENDING_METHODS.includes?(node.name)
    end
  end
end
