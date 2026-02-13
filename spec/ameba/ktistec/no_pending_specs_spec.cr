require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_pending_specs"

Spectator.describe Ameba::Rule::Ktistec::NoPendingSpecs do
  let(rule) { described_class.new }

  it "reports xdescribe" do
    source = Ameba::Source.new %(
      xdescribe "something" do
        it "does something" do
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("pending")
  end

  it "reports xcontext" do
    source = Ameba::Source.new %(
      describe "something" do
        xcontext "in some state" do
          it "does something" do
          end
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports xit" do
    source = Ameba::Source.new %(
      describe "something" do
        xit "does something" do
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports pending" do
    source = Ameba::Source.new %(
      describe "something" do
        pending "does something" do
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports multiple pending markers" do
    source = Ameba::Source.new %(
      xdescribe "something" do
        xcontext "in some state" do
          xit "does this" do
          end
          pending "does that" do
          end
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(4)
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
      xdescribe "something" do
      end
    ), "src/models/object.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag calls with receivers" do
    source = Ameba::Source.new %(
      describe "something" do
        it "does something" do
          result = SomeClass.pending(:thing)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
