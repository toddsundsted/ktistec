require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/parse_html_whitelist"

Spectator.describe Ameba::Rule::Ktistec::ParseHtmlWhitelist do
  let(rule) { described_class.new }

  it "reports `parse_html` outside the whitelist" do
    source = Ameba::Source.new %(
      XML.parse_html(content)
    ), "src/utils/foo.cr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
    expect(source.issues.first.message).to contain("parse_fragment")
  end

  it "reports `parse_html` at multiple call sites" do
    source = Ameba::Source.new %(
      XML.parse_html(a)
      XML.parse_html(b, options)
    ), "src/utils/foo.cr"

    rule.test(source)
    expect(source.issues.size).to eq(2)
  end

  it "reports `parse_html` in a .slang template" do
    source = Ameba::Source.new %(
      XML.parse_html(content)
    ), "src/views/partials/object.html.slang"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "reports `parse_html` in an .ecr template" do
    source = Ameba::Source.new %(
      XML.parse_html(content)
    ), "src/views/actors/actor.json.ecr"

    rule.test(source)
    expect(source.issues.size).to eq(1)
  end

  it "allows `parse_html` under spec/" do
    source = Ameba::Source.new %(
      XML.parse_html(content)
    ), "spec/utils/foo_spec.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag `parse_fragment`" do
    source = Ameba::Source.new %(
      Ktistec::Util.parse_fragment(content)
    ), "src/utils/foo.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "does not flag other XML parse calls" do
    source = Ameba::Source.new %(
      XML.parse(content)
    ), "src/utils/foo.cr"

    rule.test(source)
    expect(source.issues).to be_empty
  end

  it "marks itself template-aware" do
    expect(rule.template_aware?).to be_true
  end
end
