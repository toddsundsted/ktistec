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

    # The backend's revision.
    #
    @[Persistent]
    property revision : String = ""

    # The id of the oldest object the version's backfills have
    # enqueued.
    #
    @[Persistent]
    property backfill_cursor : Int64?

    # Records that every candidate from `id` up has been asked about.
    #
    # Never moves the cursor up.
    #
    def cover_down_to(id : Int64) : Nil
      query = <<-SQL
        UPDATE feed_versions
           SET backfill_cursor = MIN(COALESCE(backfill_cursor, ?), ?)
         WHERE id = ?
        RETURNING backfill_cursor
      SQL
      self.backfill_cursor = Ktistec.database.query_one(query, id, id, self.id, as: Int64?)
    end

    # Returns the version for an owner, a backend and a params, at the
    # backend's revision, creating it if it does not exist.
    #
    # Raises if the backend is not registered.
    #
    def self.for(owner : ActivityPub::Actor, backend : String, params : Hash(String, JSON::Any)) : self
      unless (registered = Backend.find?(backend))
        raise "is not a registered backend: #{backend}"
      end
      canonical = canonicalize(JSON::Any.new(registered.judging_params(params))).to_json
      revision = registered.revision(params)
      find?(owner: owner, backend: backend, params: canonical, revision: revision) ||
        new(owner: owner, backend: backend, params: canonical, revision: revision).save
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
