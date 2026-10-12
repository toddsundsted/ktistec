require "json"

require "../../framework/model"
require "../../framework/model/common"
require "../../services/feed/backend"

class Feed
  # A feed version.
  #
  class Version
    include Ktistec::Model
    include Ktistec::Model::Common

    @@table_name = "feed_versions"

    @[Persistent]
    property owner_iri : String
    belongs_to owner, class_name: ActivityPub::Actor, foreign_key: owner_iri, primary_key: iri

    @[Persistent]
    property backend : String

    # The judging params, canonicalized and serialized to JSON.
    #
    @[Persistent]
    property params : String

    # Returns the version for an owner, a backend and a params,
    # creating it if it does not exist.
    #
    # Raises if the backend is not registered.
    #
    def self.for(owner : ActivityPub::Actor, backend : String, params : Hash(String, JSON::Any)) : self
      unless (registered = Backend.find?(backend))
        raise "is not a registered backend: #{backend}"
      end
      canonical = canonicalize(JSON::Any.new(registered.judging_params(params))).to_json
      find?(owner: owner, backend: backend, params: canonical) ||
        new(owner: owner, backend: backend, params: canonical).save
    end

    # Orders every object's keys, so equal params serialize equally.
    #
    private def self.canonicalize(value : JSON::Any) : JSON::Any
      if (hash = value.as_h?)
        JSON::Any.new(hash.to_a.sort_by!(&.[0]).to_h.transform_values { |element| canonicalize(element) })
      else
        value
      end
    end
  end
end
