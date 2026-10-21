require "../../../src/services/feed/backend"

# Registers a backend for each example in the enclosing group, and
# removes it after.
#
macro register_backend(name, backend)
  around_each do |proc|
    Feed::Backend.register({{name}}, {{backend}})
    begin
      proc.call
    ensure
      Feed::Backend.unregister({{name}})
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
