require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_alternatives_in_specs"

Spectator.describe Ameba::Rule::Ktistec::NoAlternativesInSpecs do
  let(rule) { described_class.new }

  it "reports `||` inside eq()" do
    source = Ameba::Source.new %(
      describe "something" do
        it "equals value" do
          expect(subject.url).to eq(a || b)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("||")
  end

  it "reports `||` inside contain()" do
    source = Ameba::Source.new %(
      describe "something" do
        it "contains value" do
          expect(list).to contain(a || b)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("||")
  end

  it "reports `||` inside match()" do
    source = Ameba::Source.new %(
      describe "something" do
        it "matches pattern" do
          expect(text).to match(a || b)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("||")
  end

  it "allows concrete values in eq()" do
    source = Ameba::Source.new %(
      describe "something" do
        it "returns url" do
          expect(subject.url).to eq("https://test.test/actors/blob")
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows method calls without alternatives in eq()" do
    source = Ameba::Source.new %(
      describe "something" do
        it "returns url" do
          expect(subject.url).to eq(urls.try(&.first?))
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows `||` outside of matchers" do
    source = Ameba::Source.new %(
      describe "something" do
        it "does something" do
          value = a || b
          expect(result).to eq(value)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "skips non-spec files" do
    source = Ameba::Source.new %(
      def foo
        eq(a || b)
      end
    ), "src/models/object.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
