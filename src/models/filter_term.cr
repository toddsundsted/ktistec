require "../framework/model"
require "../framework/model/common"

# Filter term.
#
class FilterTerm
  include Ktistec::Model
  include Ktistec::Model::Common

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

  # Returns true if any of the actor's filter terms match the given
  # content.
  #
  # The content is HTML-stripped before matching, and each term is a
  # `SQL LIKE` pattern.
  #
  def self.match?(actor : ActivityPub::Actor, content : String?) : Bool
    return false unless (actor_id = actor.id) && content
    !where("actor_id = ? AND like(term, strip(?), '\\')", actor_id, content).empty?
  end

  # for compatibility with the ActivityPub collection view
  def iri
    "#{Ktistec.host}/filters/#{@id}"
  end
end
