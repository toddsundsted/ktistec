require "../framework/model"
require "../framework/model/**"

# Filter term.
#
class FilterTerm
  include Ktistec::Model(Common)

  @@table_name = "filter_terms"

  @[Persistent]
  property actor_id : Int64?
  belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_id, primary_key: id, inverse_of: filter_terms
  validates(actor) { "missing: #{actor_id}" unless actor? }

  @[Persistent]
  property term : String
  validates(term) do
    if !term.presence
      "can't be blank"
    elsif (instance = self.class.where(actor: actor, term: term).first?) && instance.id != self.id
      "already exists: #{term}"
    end
  end
end
