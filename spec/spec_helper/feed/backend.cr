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

# Base class for stub backends in specs.
#
# Answers every part of the contract except `validate_params`
# and `judge`.
#
abstract class TestBackend < Feed::Backend
  def revision(params : Hash(String, JSON::Any)) : String
    "test"
  end

  def cost(params : Hash(String, JSON::Any)) : Cost
    Cost.new(batch_size: 1)
  end
end
