require "ameba"

module Ameba::Rule::Ktistec
  # Prevents direct factory method calls in specs.
  #
  # Prefer declarative factory helpers (`let_build`, `let_create`)
  # over factory method calls (e.g., `actor_factory`, `poll_factory`).
  #
  class NoDirectFactoryCalls < Base
    properties do
      description "Prefer declarative factory helpers over direct factory method calls."
      excluded_factories ["env_factory"]
      enabled true
    end

    MSG = <<-MSG
      Avoid calling factory methods (e.g., xyz_factory) directly in specs.

      Prefer declarative factory helpers:
        let_build(:type, ...)   instead of let(name) { type_factory(...) }
        let_create(:type, ...)  for persisted objects
        let_build!(:type, ...)  for immediate evaluation
        let_create!(:type, ...) for immediate evaluation with persistence
      MSG

    def test(source)
      return unless source.path.ends_with?("_spec.cr")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name.ends_with?("_factory")

      return if excluded_factories.includes?(node.name)

      return if node.obj

      issue_for node, MSG
    end
  end
end
