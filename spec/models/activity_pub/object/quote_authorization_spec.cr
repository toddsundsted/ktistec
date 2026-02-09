require "../../../../src/models/activity_pub/object/quote_authorization"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Object::QuoteAuthorization do
  setup_spec

  describe ".map" do
    let(attrs) { ActivityPub::Object::QuoteAuthorization.map(json_string) }
    let(quote_decision) { attrs["quote_decision"].as(QuoteDecision) }

    context "with interactingObject and interactionTarget" do
      let(json_string) do
        <<-JSON
        {
          "@context": [
            "https://www.w3.org/ns/activitystreams",
            {
              "gts": "https://gotosocial.org/ns#",
              "interactingObject": "gts:interactingObject",
              "interactionTarget": "gts:interactionTarget"
            }
          ],
          "type": "QuoteAuthorization",
          "id": "https://remote/stamps/123",
          "interactingObject": "https://remote/posts/456",
          "interactionTarget": "https://test.test/objects/789"
        }
        JSON
      end

      it "extracts interacting_object_iri" do
        expect(quote_decision.interacting_object_iri).to eq("https://remote/posts/456")
      end

      it "extracts interaction_target_iri" do
        expect(quote_decision.interaction_target_iri).to eq("https://test.test/objects/789")
      end

      it "sets decision to accept" do
        expect(quote_decision.decision).to eq("accept")
      end
    end

    context "without quote-specific fields" do
      let(json_string) do
        <<-JSON
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "type": "QuoteAuthorization",
          "id": "https://remote/stamps/123"
        }
        JSON
      end

      it "creates quote_decision with nil IRIs" do
        expect(quote_decision.interacting_object_iri).to be_nil
        expect(quote_decision.interaction_target_iri).to be_nil
      end
    end
  end

  describe ".from_json_ld" do
    let(json_string) do
      <<-JSON
      {
        "@context": [
          "https://www.w3.org/ns/activitystreams",
          {
            "QuoteAuthorization": "https://w3id.org/fep/044f#QuoteAuthorization",
            "gts": "https://gotosocial.org/ns#",
            "interactingObject": {
              "@id": "gts:interactingObject",
              "@type": "@id"
            },
            "interactionTarget": {
              "@id": "gts:interactionTarget",
              "@type": "@id"
            }
          }
        ],
        "type": "QuoteAuthorization",
        "id": "https://remote/stamps/123",
        "attributedTo": "https://remote/actors/alice",
        "interactingObject": "https://remote/posts/456",
        "interactionTarget": "https://test.test/objects/789"
      }
      JSON
    end

    let(quote_authorization) { ActivityPub::Object.from_json_ld(json_string) }

    it "creates ActivityPub::Object::QuoteAuthorization" do
      expect(quote_authorization).to be_a(ActivityPub::Object::QuoteAuthorization)
    end

    it "extracts attributed_to_iri" do
      expect(quote_authorization.attributed_to_iri).to eq("https://remote/actors/alice")
    end

    it "has a quote_decision" do
      expect(quote_authorization.as(ActivityPub::Object::QuoteAuthorization).quote_decision?).to_not be_nil
    end

    it "extracts interacting_object_iri" do
      decision = quote_authorization.as(ActivityPub::Object::QuoteAuthorization).quote_decision
      expect(decision.interacting_object_iri).to eq("https://remote/posts/456")
    end

    it "extracts interaction_target_iri" do
      decision = quote_authorization.as(ActivityPub::Object::QuoteAuthorization).quote_decision
      expect(decision.interaction_target_iri).to eq("https://test.test/objects/789")
    end
  end

  describe "#from_json_ld" do
    let_create!(:quote_decision)
    let(quote_authorization) { quote_decision.quote_authorization }

    let(json_string) do
      <<-JSON
      {
        "@context": [
          "https://www.w3.org/ns/activitystreams",
          {
            "QuoteAuthorization": "https://w3id.org/fep/044f#QuoteAuthorization",
            "gts": "https://gotosocial.org/ns#",
            "interactingObject": {
              "@id": "gts:interactingObject",
              "@type": "@id"
            },
            "interactionTarget": {
              "@id": "gts:interactionTarget",
              "@type": "@id"
            }
          }
        ],
        "id": #{quote_authorization.iri.to_json},
        "type": "QuoteAuthorization",
        "interactingObject": "https://remote/posts/999",
        "interactionTarget": "https://test.test/objects/888"
      }
      JSON
    end

    it "replaces quote_decision instance" do
      expect { quote_authorization.from_json_ld(json_string) }.to change { quote_authorization.quote_decision }.from(quote_decision)
    end

    it "updates interacting_object_iri" do
      expect { quote_authorization.from_json_ld(json_string) }.to change { quote_authorization.quote_decision.interacting_object_iri }.to("https://remote/posts/999")
    end

    it "updates interaction_target_iri" do
      expect { quote_authorization.from_json_ld(json_string) }.to change { quote_authorization.quote_decision.interaction_target_iri }.to("https://test.test/objects/888")
    end
  end

  describe "#save" do
    let_create(:quote_authorization)

    it "deletes old quote_decision when saving new quote_decision" do
      old_decision = QuoteDecision.new(
        quote_authorization: quote_authorization,
        interacting_object_iri: "https://remote/posts/old",
        interaction_target_iri: "https://test.test/objects/old"
      ).save
      expect(old_decision.id).not_to be_nil

      expect(QuoteDecision.count(quote_authorization: quote_authorization)).to eq(1)

      new_decision = QuoteDecision.new(
        quote_authorization: quote_authorization,
        interacting_object_iri: "https://remote/posts/new",
        interaction_target_iri: "https://test.test/objects/new"
      ).save
      expect(new_decision.id).not_to be_nil

      expect(new_decision.id).not_to eq(old_decision.id)

      expect(QuoteDecision.count(quote_authorization: quote_authorization, include_deleted: true, include_undone: true)).to eq(1)
      expect(QuoteDecision.find?(old_decision.id)).to be_nil
      expect(QuoteDecision.find(new_decision.id)).not_to be_nil
    end
  end
end
