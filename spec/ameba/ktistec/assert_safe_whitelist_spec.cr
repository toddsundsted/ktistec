require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/assert_safe_whitelist"

Spectator.describe Ameba::Rule::Ktistec::AssertSafeWhitelist do
  let(rule) { described_class.new }

  it "reports `assert_safe` outside the whitelist" do
    source = Ameba::Source.new %(
      Ktistec::SafeHTML.assert_safe(value)
    ), "src/controllers/foo.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("typed-trust escape hatch")
  end

  it "reports `assert_safe` at multiple call sites" do
    source = Ameba::Source.new %(
      Ktistec::SafeHTML.assert_safe(a)
      Ktistec::SafeAttrValue.assert_safe(b)
      Ktistec::SafeURI.assert_safe(c)
    ), "src/controllers/foo.cr"

    rule.test(source)
    expect(source.issues.size).to eq(3)
  end

  it "reports `assert_safe` in a .slang template" do
    source = Ameba::Source.new %(
      Ktistec::SafeHTML.assert_safe(value)
    ), "src/views/partials/object.html.slang"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "allows `assert_safe` in src/utils/paths.cr" do
    source = Ameba::Source.new %(
      Ktistec::SafeURI.assert_safe("/x")
    ), "src/utils/paths.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows `assert_safe` in src/framework/util.cr" do
    source = Ameba::Source.new %(
      Ktistec::SafeHTML.assert_safe(result)
    ), "src/framework/util.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows `assert_safe` under src/views/helpers/" do
    source = Ameba::Source.new %(
      Ktistec::SafeHTML.assert_safe("<i></i>")
    ), "src/views/helpers/theming_helpers.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows `assert_safe` under spec/" do
    source = Ameba::Source.new %(
      Ktistec::SafeURI.assert_safe("/x")
    ), "spec/controllers/foo_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag method definition" do
    source = Ameba::Source.new %(
      class SafeHTML
        def self.assert_safe(s : String) : SafeHTML
          new(s)
        end
      end
    ), "src/safe/safe_html.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag unrelated calls" do
    source = Ameba::Source.new %(
      something_else(value)
      assert(value)
    ), "src/controllers/foo.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "marks itself slang-aware" do
    expect(rule.slang_aware?).to be_true
  end
end
