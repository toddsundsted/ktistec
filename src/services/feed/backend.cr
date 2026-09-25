require "json"

require "../../models/feed"
require "../../models/activity_pub/object"

class Feed
  # Base class for feed judges.
  #
  # The interface between a feed and whatever decides membership: a
  # backend is given a feed's config and a batch of posts and returns
  # a per-post verdict -- `{included, reason}` -- with order and
  # identity preserved.
  #
  abstract class Backend
    # A verdict: in or out, and why.
    #
    record Judgment, included : Bool, reason : String? = nil

    # Judges a batch of objects for a feed.
    #
    # Returns one `Judgment` per object, in the same order.
    #
    abstract def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)

    # Validates a feed's backend-owned params.
    #
    # Returns error messages -- empty if the params are valid. Each
    # message should be a complete sentence and is rendered verbatim.
    #
    abstract def validate_params(params : Hash(String, JSON::Any)) : Array(String)

    # Returns a feed's params reduced to what decides membership.
    #
    # In canonical form. Compared, never stored.
    #
    def judging_params(params : Hash(String, JSON::Any)) : Hash(String, JSON::Any)
      params
    end

    # Reports the judge's revision given a feed's params.
    #
    # Changes when a change to the judge would change its answers.
    #
    abstract def revision(params : Hash(String, JSON::Any)) : String

    # A judge's declared appetite.
    #
    record Cost,
      batch_size : Int32

    # Declares the judge's cost given a feed's params.
    #
    abstract def cost(params : Hash(String, JSON::Any)) : Cost

    # A judging failure.
    #
    abstract class Error < Exception
    end

    class TransientError < Error
    end

    class PermanentError < Error
    end

    @@registry = {} of String => Backend

    # Registers a backend.
    #
    def self.register(name : String, backend : Backend) : Backend
      @@registry[name] = backend
    end

    # Returns the backend.
    #
    def self.find?(name : String) : Backend?
      @@registry[name]?
    end
  end
end
