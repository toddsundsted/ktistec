require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_eq_boolean_in_specs"

Spectator.describe Ameba::Rule::Ktistec::NoEqBooleanInSpecs do
  let(rule) { described_class.new }

  it "reports eq(true)" do
    source = Ameba::Source.new %(
      describe "something" do
        it "is true" do
          expect(result).to eq(true)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("be_true")
  end

  it "reports eq(false)" do
    source = Ameba::Source.new %(
      describe "something" do
        it "is false" do
          expect(result).to eq(false)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("be_false")
  end

  it "allows be_true" do
    source = Ameba::Source.new %(
      describe "something" do
        it "is true" do
          expect(result).to be_true
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows be_false" do
    source = Ameba::Source.new %(
      describe "something" do
        it "is false" do
          expect(result).to be_false
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows eq() with non-boolean values" do
    source = Ameba::Source.new %(
      describe "something" do
        it "equals value" do
          expect(result).to eq(42)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "skips non-spec files" do
    source = Ameba::Source.new %(
      def foo
        eq(true)
      end
    ), "src/models/object.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
