require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_redundant_factory_name"

Spectator.describe Ameba::Rule::Ktistec::NoRedundantFactoryName do
  let(rule) { described_class.new }

  it "reports a redundant named argument with a symbol type" do
    source = Ameba::Source.new %(
      describe "test" do
        let_create!(:object, named: object, attributed_to: author)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("redundant")
  end

  it "reports a redundant named argument with a bare-word type" do
    source = Ameba::Source.new %(
      describe "test" do
        let_build(object, named: object)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports across all factory helpers" do
    source = Ameba::Source.new %(
      describe "test" do
        let_build(:object, named: object)
        let_build!(:object, named: object)
        let_create(:object, named: object)
        let_create!(:object, named: object)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues.size).to eq(4)
  end

  it "does not flag a named argument with a distinct name" do
    source = Ameba::Source.new %(
      describe "test" do
        let_create!(:object, named: post)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag an anonymous name" do
    source = Ameba::Source.new %(
      describe "test" do
        let_create!(:object, named: nil)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag a helper without a name" do
    source = Ameba::Source.new %(
      describe "test" do
        let_create!(:object, attributed_to: author)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag non-factory calls" do
    source = Ameba::Source.new %(
      describe "test" do
        some_helper(:object, named: object)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "skips non-spec files" do
    source = Ameba::Source.new %(
      let_create!(:object, named: object)
    ), "spec/spec_helper/factory.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "removes a redundant named argument in the middle of the arguments" do
    source = Ameba::Source.new %(
      describe "test" do
        let_create!(:object, named: object, attributed_to: author)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.correct?).to be_true
    expect(source.code).to contain("let_create!(:object, attributed_to: author)")
    expect(source.code).not_to contain("named:")
  end

  it "removes a redundant named argument with a symbol value" do
    source = Ameba::Source.new %(
      describe "test" do
        let_build(:actor, named: :actor)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.correct?).to be_true
    expect(source.code).to contain("let_build(:actor)")
    expect(source.code).not_to contain("named:")
  end

  it "removes a redundant named argument with a bare-word value" do
    source = Ameba::Source.new %(
      describe "test" do
        let_build(actor, named: actor)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.correct?).to be_true
    expect(source.code).to contain("let_build(actor)")
    expect(source.code).not_to contain("named:")
  end

  it "removes a redundant named argument at the end of the arguments" do
    source = Ameba::Source.new %(
      describe "test" do
        let_create!(:object, named: object)
      end
    ), "spec/models/object_spec.cr"

    rule.test(source)
    expect(source.correct?).to be_true
    expect(source.code).to contain("let_create!(:object)")
    expect(source.code).not_to contain("named:")
  end

  it "removes a redundant named argument spanning multiple lines" do
    source = Ameba::Source.new <<-CRYSTAL, "spec/models/object_spec.cr"
      describe "test" do
        let_create!(:object,
          named: object,
          attributed_to: author)
      end
      CRYSTAL

    rule.test(source)
    expect(source.correct?).to be_true
    expect(source.code).to contain("attributed_to: author)")
    expect(source.code).not_to contain("named:")
  end
end
