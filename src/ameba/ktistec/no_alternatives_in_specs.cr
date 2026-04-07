require "ameba"

module Ameba::Rule::Ktistec
  # Prevents `||` inside spec matchers.
  #
  # Spec expectations should assert against concrete, known values.
  # An `||` in a matcher argument indicates the test doesn't know
  # what to expect, which defeats the purpose of the assertion.
  #
  # This is considered invalid:
  #
  # ```
  # expect(subject.url).to eq(actor.urls.try(&.first?) || actor.iri)
  # ```
  #
  # And should be written as:
  #
  # ```
  # expect(subject.url).to eq("https://test.test/actors/blob")
  # ```
  #
  class NoAlternativesInSpecs < Base
    properties do
      description "Spec matchers should not contain `||` alternatives."
      enabled true
    end

    MATCHERS = %w[eq be contain match be_close start_with end_with have_attributes]

    MSG = <<-MSG
      Avoid `||` in spec matchers.

      Expectations should assert against concrete values, not alternatives:
        eq(a || b)  ->  eq(a)
      MSG

    def test(source)
      return unless source.path.ends_with?("_spec.cr")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless MATCHERS.includes?(node.name)

      node.args.each do |arg|
        visitor = OrVisitor.new(arg)
        if visitor.found?
          issue_for node, MSG
          return
        end
      end
    end

    private class OrVisitor < Crystal::Visitor
      getter? found = false

      def initialize(node : Crystal::ASTNode)
        node.accept(self)
      end

      def visit(node : Crystal::Or)
        @found = true
        false
      end

      def visit(node : Crystal::ASTNode)
        !@found
      end
    end
  end
end
