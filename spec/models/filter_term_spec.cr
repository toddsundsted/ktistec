require "../../src/models/filter_term"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe FilterTerm do
  setup_spec

  it "instantiates the class" do
    expect(described_class.new(term: "term")).to be_a(FilterTerm)
  end

  describe ".match?" do
    let_create(:actor)

    it "returns false" do
      expect(described_class.match?(actor, "this is spam, really")).to be_false
    end

    context "given a filter term" do
      let_create!(:filter_term, actor: actor, term: "%spam%")

      it "matches content containing the term" do
        expect(described_class.match?(actor, "this is spam, really")).to be_true
      end

      it "strips HTML markup before matching" do
        expect(described_class.match?(actor, "this is <b>sp</b>am, really")).to be_true
      end

      it "does not match content without the term" do
        expect(described_class.match?(actor, "this is clean, really")).to be_false
      end

      it "does not match nil content" do
        expect(described_class.match?(actor, nil)).to be_false
      end

      let_create(:actor, named: other)

      it "does not match another actor's content" do
        expect(described_class.match?(other, "this is spam, really")).to be_false
      end
    end
  end
end
