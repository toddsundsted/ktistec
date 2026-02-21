require "../object"
require "../../quote_decision"

class ActivityPub::Object
  class QuoteAuthorization < ActivityPub::Object
    has_one quote_decision, foreign_key: quote_authorization_iri, primary_key: iri, inverse_of: quote_authorization

    def before_save
      super
      self.special ||= "quote_authorization"
    end

    # Validates this quote authorization.
    #
    # Returns `true` if this quote authorization correctly authorizes
    # `quoting_object` to quote `quoted_object`, `false` otherwise.
    #
    def valid_for?(quoting_object : ActivityPub::Object, quoted_object : ActivityPub::Object) : Bool
      !!(quote_decision = quote_decision?) &&
        quote_decision.interacting_object? == quoting_object &&
        quote_decision.interaction_target? == quoted_object &&
        attributed_to? == quoted_object.attributed_to?
    end

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
