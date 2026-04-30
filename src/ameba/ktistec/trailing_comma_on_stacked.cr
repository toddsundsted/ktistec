require "ameba"

module Ameba::Rule::Ktistec
  # Enforces trailing commas on stacked arguments and collection elements.
  class TrailingCommaOnStacked < Base
    properties do
      description "Enforce trailing commas on stacked arguments and collection elements"
      enabled true
    end

    MSG_MISSING   = "Add a trailing comma after the last item in a stacked list."
    MSG_REDUNDANT = "Remove the redundant trailing comma before the closing delimiter."

    def test(source)
      visitor = StackedItemsVisitor.new(source)
      visitor.missing_violations.each do |location|
        issue_for location, location, MSG_MISSING do |corrector|
          corrector.insert_after(location, ",")
        end
      end
      visitor.redundant_violations.each do |location|
        issue_for location, location, MSG_REDUNDANT do |corrector|
          corrector.remove(location, location)
        end
      end
    end

    # `NodeVisitor` doesn't visit `ArrayLiteral`, so introduce a
    # custom visitor that handles all three node types directly.
    private class StackedItemsVisitor < Crystal::Visitor
      getter missing_violations = [] of Crystal::Location
      getter redundant_violations = [] of Crystal::Location

      def initialize(@source : Ameba::Source)
        @source.ast.accept(self)
      end

      def visit(node : Crystal::Call)
        # only check calls that use parentheses. non-parenthesized
        # calls (e.g. `foo a, b` or `ok "template", key: value`) don't
        # support trailing commas. Also skip indexed assignment
        # (e.g. []=).
        if node.has_parentheses? && node.name != "[]="
          last = if (named = node.named_args) && !named.empty?
                   named.last.as(Crystal::ASTNode)
                 elsif !node.args.empty?
                   node.args.last
                 end
          check_last_item(last) if last
        end
        true
      end

      def visit(node : Crystal::ArrayLiteral)
        # skip word/symbol array literals (e.g. %w[], %i[]). items are
        # whitespace-separated and adding a comma corrupts them.
        unless node.of || node.elements.empty?
          check_last_item(node.elements.last)
        end
        true
      end

      def visit(node : Crystal::HashLiteral)
        unless node.entries.empty?
          check_last_item(node.entries.last)
        end
        true
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      # Checks the item for missing or redundant trailing comma.
      #
      # - missing: nothing (or only whitespace) follows on the same
      #   line
      # - redundant: a comma and a closing delimiter both follow on
      #   the same line
      #
      private def check_last_item(item)
        # skip if the last item is a heredoc literal
        return if heredoc?(item)

        last_end = item_end_location(item)
        return if last_end.nil?

        line = @source.lines[last_end.line_number - 1]?
        return if line.nil?

        after_last = line[(last_end.column_number)..]?
        return if after_last.nil?

        if after_last.matches?(/\A\s*,\s*[\)\]\}]/)
          comma_offset = after_last.index!(',')
          comma_column = last_end.column_number + comma_offset + 1
          comma_location = Crystal::Location.new(last_end.filename, last_end.line_number, comma_column)
          @redundant_violations << comma_location
        elsif !after_last.matches?(/\A\s*[,\)\]\}]/)
          @missing_violations << last_end
        end
      end

      # Returns true if the item is a heredoc literal.
      #
      private def heredoc?(item) : Bool
        location =
          case item
          when Crystal::HashLiteral::Entry
            item.value.location
          when Crystal::NamedArgument
            item.value.location
          else
            item.location
          end
        return false if location.nil?
        line = @source.lines[location.line_number - 1]?
        return false if line.nil?
        segment = line[(location.column_number - 1)..]?
        segment ? segment.starts_with?("<<") : false
      end

      private def item_end_location(item) : Crystal::Location?
        case item
        when Crystal::HashLiteral::Entry
          item.value.end_location
        else
          item.end_location
        end
      end
    end
  end
end
