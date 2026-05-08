require "ameba"

module Ameba::Rule::Ktistec
  # Restricts `assert_safe` calls to an audited whitelist of files.
  #
  # `assert_safe` promotes a plain `String` to a typed `Safe` value
  # with no encoding or validation. It is the typed-trust escape
  # hatch: every call site is a manual security assertion that the
  # wrapped bytes are safe in the destination context.
  #
  class AssertSafeWhitelist < Base
    properties do
      description "Restricts `assert_safe` calls to audited producer files."
      enabled true
      severity :warning
      whitelist [
        "src/utils/paths.cr",
        "src/framework/util.cr",
        "src/views/helpers/*.cr",
        "spec/**/*.cr",
      ]
    end

    MSG = <<-MSG
      `assert_safe` is the typed-trust escape hatch; this file is not in
      the audited whitelist.

      Each call bypasses the encoders/sanitizers and asserts that the
      wrapped String is already safe in its destination context. Audit
      the call site and, if intentional, add the file to
      `Ktistec/AssertSafeWhitelist:Whitelist` in `.ameba.yml`.
      MSG

    def test(source)
      return if whitelisted?(source.path)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      issue_for node, MSG if node.name == "assert_safe"
    end

    # slang-derived sources should be checked too. `assert_safe` does
    # not belong in a template.

    def slang_aware? : Bool
      true
    end

    private def whitelisted?(path : String) : Bool
      whitelist.any? { |pattern| File.match?(pattern, path) }
    end
  end
end
