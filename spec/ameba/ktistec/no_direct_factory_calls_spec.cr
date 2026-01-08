require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_direct_factory_calls"

Spectator.describe Ameba::Rule::Ktistec::NoDirectFactoryCalls do
  let(rule) { described_class.new }

  it "reports direct factory method calls" do
    source = Ameba::Source.new %(
      describe "test" do
        let(poll) do
          poll_factory(question: object)
        end
      end
    ), "spec/models/poll_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("Prefer declarative factory helpers")
  end

  it "reports multiple direct factory method calls" do
    source = Ameba::Source.new %(
      describe "test" do
        let(poll) { poll_factory(question: object) }
        let(actor) { actor_factory }
      end
    ), "spec/models/test_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(2)
  end

  it "allows declarative factory helpers" do
    source = Ameba::Source.new %(
      describe "test" do
        let_build(:poll, question: object)
        let_create(:actor)
      end
    ), "spec/models/test_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows factory method calls with receivers" do
    source = Ameba::Source.new %(
      describe "test" do
        let(poll) { SomeModule.poll_factory(question: object) }
      end
    ), "spec/models/poll_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "allows method definitions" do
    source = Ameba::Source.new %(
      def poll_factory(question = nil, **options)
        Poll.new(question: question)
      end

      def actor_factory(**options)
        Actor.new
      end
    ), "spec/spec_helper/factory.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "skips non-spec files" do
    source = Ameba::Source.new %(
      poll_factory(question: object)
    ), "spec/data/polls.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "reports non-excluded factories" do
    rule.excluded_factories = ["env_factory"]

    source = Ameba::Source.new %(
      describe "test" do
        let(env) { env_factory("GET", "/path") }
        let(poll) { poll_factory(question: object) }
      end
    ), "spec/controllers/test_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "allows excluded factories" do
    source = Ameba::Source.new %(
      describe "test" do
        let(env) { env_factory("GET", "/path") }
      end
    ), "spec/controllers/test_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end
end
