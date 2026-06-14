require "ameba"

module Ameba::Rule::Ktistec
  # Flags redundant `named:` arguments on declarative factory helpers.
  #
  class NoRedundantFactoryName < Base
    properties do
      description "Avoid redundant `named:` arguments on factory helpers."
      enabled true
    end

    MACROS = %w[let_build let_build! let_create let_create!]

    MSG = <<-MSG
      Avoid redundant `named:` argument on factory helper.

      The factory already names the value after its type, so this
      `named:` is redundant. Use `named:` only to avoid a collision:
      give the value a distinct name, or pass `named: nil` for an
      anonymous value.
      MSG

    def test(source)
      return unless source.path.ends_with?("_spec.cr")

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return if node.obj
      return unless MACROS.includes?(node.name)

      named_args = node.named_args
      return unless named_args
      named_arg = named_args.find { |arg| arg.name == "named" }
      return unless named_arg

      type = node.args.first?
      return unless type

      type_name = identifier(type)
      return unless type_name
      named_name = identifier(named_arg.value)
      return unless named_name && named_name == type_name

      value = named_arg.value
      start_location = value.location
      end_location = value.end_location

      if start_location && end_location &&
         (comma = source.code.rindex(',', source.pos(start_location) - 1))
        issue_for named_arg, MSG do |corrector|
          corrector.remove(comma...(source.pos(end_location) + 1))
        end
      else
        issue_for named_arg, MSG
      end
    end

    private def identifier(node : Crystal::ASTNode?) : String?
      case node
      when Crystal::SymbolLiteral
        node.value
      when Crystal::StringLiteral
        node.value
      when Crystal::Path
        node.names.first if node.names.size == 1
      when Crystal::Var
        node.name
      when Crystal::Call
        node.name if node.obj.nil? && node.args.empty? && node.named_args.nil? && node.block.nil?
      end
    end
  end
end
