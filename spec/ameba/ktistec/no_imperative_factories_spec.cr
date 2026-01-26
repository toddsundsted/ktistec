require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_imperative_factories"

Spectator.describe Ameba::Rule::Ktistec::NoImperativeFactories do
  let(rule) { described_class.new }

  it "reports Factory.build calls" do
    source = Ameba::Source.new %(
      describe "test" do
        it "creates object" do
          object = Factory.build(:object)
        end
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("Prefer declarative factory helpers")
  end

  it "reports Factory.create calls" do
    source = Ameba::Source.new %(
      describe "test" do
        it "creates actor" do
          actor = Factory.create(:actor)
        end
      end
    ), "spec/models/actor_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports Factory calls in let blocks" do
    source = Ameba::Source.new %(
      describe "test" do
        let(object) { Factory.build(:object) }
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports multiple Factory calls" do
    source = Ameba::Source.new %(
      describe "test" do
        it "creates objects" do
          object = Factory.build(:object)
          actor = Factory.create(:actor)
        end
      end
    ), "spec/models/test_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(2)
  end

  it "allows declarative factory helpers" do
    source = Ameba::Source.new %(
      describe "test" do
        let_build(:object)
        let_create(:actor)
      end
    ), "spec/models/test_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "skips non-spec files" do
    source = Ameba::Source.new %(
      Factory.build(:object)
    ), "spec/data/objects.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag non-Factory receivers" do
    source = Ameba::Source.new %(
      describe "test" do
        it "does something" do
          result = SomeClass.build(:object)
        end
      end
    ), "spec/models/test_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
