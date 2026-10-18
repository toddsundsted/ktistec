require "json"

require "../../models/feed"
require "../../models/activity_pub/object"

class Feed
  # Base class for feed judges.
  #
  # The interface between a feed and whatever decides membership: a
  # backend is given a feed's config and a batch of posts and returns
  # a per-post verdict -- `{included, reason}` or `{failure, reason}`
  # -- with order and identity preserved.
  #
  abstract class Backend
    # A verdict: in or out, and why.
    #
    record Judgment, included : Bool, reason : String? = nil

    # A failure, and why.
    #
    record Failure, kind : Kind, reason : String? = nil do
      enum Kind
        Transient
        Permanent
      end
    end

    # Judges a batch of objects for a feed.
    #
    # Returns one `Judgment` or `Failure` per object, in the same order.
    #
    # Raises if the judge can't answer for the entire batch.
    #
    abstract def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)

    # Validates a feed's backend-owned params.
    #
    # Returns error messages -- empty if the params are valid. Each
    # message should be a complete sentence and is rendered verbatim.
    #
    abstract def validate_params(params : Hash(String, JSON::Any)) : Array(String)

    # Returns a feed's params reduced to what decides membership.
    #
    # In canonical form.
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

    # Unregisters a backend.
    #
    def self.unregister(name : String) : Nil
      @@registry.delete(name)
    end

    # Returns the registered backend for a name, or `nil`.
    #
    def self.find?(name : String) : Backend?
      @@registry[name]?
    end

    # Returns the names of the registered backends.
    #
    def self.names : Array(String)
      @@registry.keys
    end
  end
end
