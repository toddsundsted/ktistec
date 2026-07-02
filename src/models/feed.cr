require "../framework/model"
require "../framework/model/common"
require "./feed/verdict"
require "../services/feed/backend"

# An algorithmic feed.
#
# A feed is a runtime-created sibling collection to the timeline whose
# membership is decided by a judge rather than by a fixed structural
# rule. The judge's verdicts are the base facts a generic materialized
# view queries.
#
class Feed
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "feeds"

  @[Persistent]
  property owner_iri : String?
  belongs_to owner, class_name: ActivityPub::Actor, foreign_key: owner_iri, primary_key: iri
  validates(owner) { "missing: #{owner_iri}" unless owner? }

  has_many verdicts, class_name: Feed::Verdict, foreign_key: feed_id, primary_key: id, inverse_of: feed

  @[Persistent]
  property name : String
  validates(name) { "can't be blank" unless name.presence }

  @[Persistent]
  property backend : String
  validates(backend) { "is not a registered backend: #{backend}" unless Backend.find?(backend) }

  @[Persistent]
  property version : Int32 = 1

  @[Persistent]
  property description : String?

  # An example of what belongs in (or doesn't belong in) the feed.
  #
  class Example
    include JSON::Serializable

    property object_iri : String
    property included : Bool

    def initialize(@object_iri : String, @included : Bool)
    end
  end

  @[Persistent]
  property examples : Array(Example) { [] of Example }

  # Backend-owned configuration.
  #
  # Opaque to everything but the backend named by `backend`.
  #
  @[Persistent]
  property params : Hash(String, JSON::Any) { {} of String => JSON::Any }
  validates(params) do
    if (backend = Backend.find?(self.backend))
      errors = backend.validate_params(params)
      errors.join(", ") unless errors.empty?
    end
  end

  # The relationship type of the feed's materialized rows.
  #
  # A synthetic, per-feed string, namespaced so it can never collide
  # with the `Relationship::**` class names. Rows carrying it must
  # never pass through `Relationship`'s polymorphic loader.
  #
  def feed_type : String
    "Feed::#{id.not_nil!}"
  end
end
