require "ameba"

module Ameba::Rule::Ktistec
  # Flags raising `JSON::Any` casts in the JSON-LD mappers.
  #
  # `as_s`, `as_h` and the other raising casts raise `TypeCastError`
  # when inbound JSON-LD has an unexpected shape. The mappers must
  # use the nil-returning `as_s?`, `as_h?`, etc.
  #
  class NoRaisingJsonCast < Base
    properties do
      description "Use nil-returning `JSON::Any` casts in the JSON-LD mappers."
      enabled true
    end

    MSG = <<-MSG
      Use `%{cast}?`, not `%{cast}`, in JSON-LD mappers.

      Mappers read remote JSON-LD, which can have any shape. `%{cast}` raises
      `TypeCastError` when the value isn't the expected type, which turns
      bad input into a 500. `%{cast}?` returns `nil` instead. Handle the `nil`,
      typically by binding the result: `if (value = json.%{cast}?)`.
      MSG

    CASTS = %w(as_s as_h as_a as_i as_i64 as_f as_f32 as_bool)

    def test(source)
      return unless source.path.includes?("src/models/activity_pub/")
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(CASTS)
      issue_for node, MSG % {cast: node.name}
    end
  end
end
