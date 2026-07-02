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
    # Returns error messages -- empty if the params are valid.
    #
    abstract def validate_params(params : Hash(String, JSON::Any)) : Array(String)

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

    # the sink that invokes a backend on a batch is isolated behind a
    # swappable proc so the wiring can be tested synchronously, and so
    # a future worker can drive the identical seam.

    DEFAULT_INVOKER = ->(backend : Backend, feed : ::Feed, objects : Array(ActivityPub::Object)) { backend.judge(feed, objects) }

    class_property invoker : Proc(Backend, ::Feed, Array(ActivityPub::Object), Array(Judgment)) = DEFAULT_INVOKER
  end
end
