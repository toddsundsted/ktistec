require "../../src/models/quote_decision"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe QuoteDecision do
  setup_spec

  describe "validation" do
    context "when quote_authorization is nil" do
      let(quote_decision) { QuoteDecision.new }

      it "must be present" do
        expect(quote_decision.valid?).to be_false
        expect(quote_decision.errors.keys).to contain("quote_authorization")
        expect(quote_decision.errors["quote_authorization"]?).to contain("must be present")
      end
    end

    context "decision is not specified" do
      let_build(:quote_decision)

      it "defaults to 'accept'" do
        expect(quote_decision.decision).to eq("accept")
      end
    end

    context "when decision is 'accept'" do
      let_build(:quote_decision, decision: "accept")

      it "is valid" do
        expect(quote_decision.valid?).to be_true
      end
    end

    context "when decision is 'reject'" do
      let_build(:quote_decision, decision: "reject")

      it "is valid" do
        expect(quote_decision.valid?).to be_true
      end
    end

    context "when decision is invalid" do
      let_build(:quote_decision, decision: "maybe")

      it "is not valid" do
        expect(quote_decision.valid?).to be_false
        expect(quote_decision.errors.keys).to contain("decision")
        expect(quote_decision.errors["decision"]?).to contain(%q|must be "accept" or "reject"|)
      end
    end
  end
end
