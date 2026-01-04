require "ameba"

# Custom Ameba Rules for Ktistec.
#
module Ameba::Rule::Ktistec
  # Prevents imperative Factory usage in specs.
  #
  # Prefer declarative factory helpers (`let_build`, `let_create`) over
  # imperative `Factory` method calls (`Factory.build`, `Factory.create`).
  #
  class NoImperativeFactories < Base
    properties do
      description "Prefer declarative factory helpers over imperative Factory method calls."
      enabled true
    end

    MSG = <<-MSG
      Avoid imperative Factory method calls in specs.

      Prefer declarative factory helpers:
        let_build(:type, ...)   instead of Factory.build(:type, ...)
        let_create(:type, ...)  instead of Factory.create(:type, ...)
        let_build!(:type, ...)  for immediate evaluation
        let_create!(:type, ...) for immediate evaluation

      Use the "writing-good-specs" skill for more guidance.
      MSG

    def test(source)
      return unless source.path.includes?("spec/")
      return if source.path.includes?("spec/spec_helper")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      obj = node.obj
      return unless obj

      if obj.is_a?(Crystal::Path)
        return unless obj.names.size == 1 && obj.names.first == "Factory"
        issue_for node, MSG
      end
    end
  end
end

require "ameba/cli"
