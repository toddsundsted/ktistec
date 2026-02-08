require "../object"
require "../../quote_decision"

class ActivityPub::Object
  class QuoteAuthorization < ActivityPub::Object
    has_one quote_decision, foreign_key: quote_authorization_iri, primary_key: iri, inverse_of: quote_authorization

    def self.map(json, **options)
      json = json.is_a?(String | IO) ? Ktistec::JSON_LD.expand(JSON.parse(json)) : json

      interacting_object_iri = Ktistec::JSON_LD.dig_id?(json, "https://gotosocial.org/ns#interactingObject")
      interaction_target_iri = Ktistec::JSON_LD.dig_id?(json, "https://gotosocial.org/ns#interactionTarget")

      super(json, **options).merge({
        "quote_decision" => QuoteDecision.new(
          interacting_object_iri: interacting_object_iri,
          interaction_target_iri: interaction_target_iri,
          decision: "accept",
        ),
      })
    end
  end
end
