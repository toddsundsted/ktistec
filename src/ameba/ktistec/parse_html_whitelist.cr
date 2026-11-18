require "ameba"

module Ameba::Rule::Ktistec
  # Restricts `parse_html` calls to a whitelist of files.
  #
  # `XML.parse_html` parses an HTML document. It does not parse HTML
  # fragments consistently across libxml versions. Parse HTML
  # fragments with `Ktistec::Util.parse_fragment`.
  #
  class ParseHtmlWhitelist < Base
    properties do
      description "Flags `parse_html` calls that aren't explicitly allowed."
      enabled true
      severity :warning
      whitelist [
        "spec/**/*.cr",
      ]
    end

    MSG = <<-MSG
      `parse_html` parses a document.

      To parse an HTML fragment, use `Ktistec::Util.parse_fragment`.
      To parse a whole document, disable this rule on that line with
      `# ameba:disable Ktistec/ParseHtmlWhitelist`.
      MSG

    def test(source)
      return if whitelisted?(source.path)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      issue_for node, MSG if node.name == "parse_html"
    end

    # template-derived sources (.slang, .ecr) should be checked too.

    def template_aware? : Bool
      true
    end

    private def whitelisted?(path : String) : Bool
      whitelist.any? { |pattern| File.match?(pattern, path) }
    end
  end
end
