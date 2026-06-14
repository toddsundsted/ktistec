require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_require_glob"

Spectator.describe Ameba::Rule::Ktistec::NoRequireGlob do
  let(rule) { described_class.new }

  it "reports a non-recursive glob require" do
    source = Ameba::Source.new %(
      require "./foo/*"
    ), "src/example.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("glob")
  end

  it "reports a recursive glob require" do
    source = Ameba::Source.new %(
      require "./foo/**"
    ), "src/example.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports a glob require resolved against the library path" do
    source = Ameba::Source.new %(
      require "foo/bar/**"
    ), "src/example.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports each glob require independently" do
    source = Ameba::Source.new %(
      require "./foo/*"
      require "./bar/**"
    ), "src/example.cr"

    rule.test(source)
    expect(source.issues.size).to eq(2)
  end

  it "does not flag a non-glob require" do
    source = Ameba::Source.new %(
      require "./foo/bar"
    ), "src/example.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag a non-glob require" do
    source = Ameba::Source.new %(
      require "./foo/*/bar"
    ), "src/example.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
