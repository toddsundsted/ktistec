require "../../src/models/translation"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Translation do
  setup_spec

  let_create(:object)

  it "it instantiates the class" do
    expect(described_class.new(origin: object)).to be_a(Translation)
  end
end
