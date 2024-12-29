require "../../src/models/filter_term"

require "../spec_helper/base"

Spectator.describe FilterTerm do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(term: "term")).to be_a(FilterTerm)
  end
end
