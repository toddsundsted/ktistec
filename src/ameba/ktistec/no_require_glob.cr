require "ameba"

module Ameba::Rule::Ktistec
  # Flags glob `require` statements.
  #
  # Crystal treats a `require` argument ending in `/*` or `/**` as a
  # wildcard: `/*` pulls in every `.cr` file directly in the directory,
  # and `/**` does so recursively.
  #
  class NoRequireGlob < Base
    properties do
      description "Avoid glob `require` statements; require files explicitly."
      enabled true
    end

    MSG = <<-MSG
      Avoid glob `require`.

      A `require` ending in `/*` or `/**` pulls in files implicitly and
      obscures load order. Require the files explicitly instead.
      MSG

    def test(source)
      nodes = AST::TopLevelNodesVisitor.new(source.ast).require_nodes
      nodes.each do |node|
        string = node.string
        if string.ends_with?("/*") || string.ends_with?("/**")
          issue_for node, MSG
        end
      end
    end
  end
end
