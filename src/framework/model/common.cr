require "../model"

module Ktistec
  module Model(*T)
    module Common
      @[Persistent]
      @[Insignificant]
      property created_at : Time { Time.utc }

      @[Persistent]
      @[Insignificant]
      property updated_at : Time { Time.utc }
    end
  end
end

# :nodoc:
module Common
end
