require "../../../src/services/feed/backend"

class Feed
  abstract class Backend
    # Removes a registered backend.
    #
    def self.unregister(name : String) : Nil
      @@registry.delete(name)
    end
  end
end
