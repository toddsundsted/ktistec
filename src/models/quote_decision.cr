require "../framework/model"
require "./activity_pub/object/quote_authorization"

class QuoteDecision
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "quote_decisions"

  alias QuoteAuthorization = ActivityPub::Object::QuoteAuthorization

  @[Persistent]
  property quote_authorization_iri : String?
  belongs_to quote_authorization, foreign_key: quote_authorization_iri, primary_key: iri, inverse_of: quote_decision
  validates(quote_authorization) { "must be present" unless quote_authorization? }

  @[Persistent]
  property interacting_object_iri : String?
  belongs_to interacting_object, class_name: ActivityPub::Object, foreign_key: interacting_object_iri, primary_key: iri

  @[Persistent]
  property interaction_target_iri : String?
  belongs_to interaction_target, class_name: ActivityPub::Object, foreign_key: interaction_target_iri, primary_key: iri

  @[Persistent]
  property decision : String { "accept" }
  validates(decision) { %q|must be "accept" or "reject"| unless decision.in?("accept", "reject") }
end
