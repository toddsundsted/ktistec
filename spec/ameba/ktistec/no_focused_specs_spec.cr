require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_focused_specs"

Spectator.describe Ameba::Rule::Ktistec::NoFocusedSpecs do
  let(rule) { described_class.new }

  it "reports fdescribe" do
    source = Ameba::Source.new %(
      fdescribe "something" do
        it "does something" do
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("focused")
  end

  it "reports fcontext" do
    source = Ameba::Source.new %(
      describe "something" do
        fcontext "in some state" do
          it "does something" do
          end
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports fit" do
    source = Ameba::Source.new %(
      describe "something" do
        fit "does something" do
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports multiple focused markers" do
    source = Ameba::Source.new %(
      fdescribe "something" do
        fcontext "in some state" do
          fit "does this" do
          end
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(3)
  end

  it "allows describe, context, and it" do
    source = Ameba::Source.new %(
      describe "something" do
        context "in some state" do
          it "does something" do
          end
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "skips non-spec files" do
    source = Ameba::Source.new %(
      fdescribe "something" do
      end
    ), "src/models/object.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag calls with receivers" do
    source = Ameba::Source.new %(
      describe "something" do
        it "does something" do
          result = SomeClass.fit(:thing)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
