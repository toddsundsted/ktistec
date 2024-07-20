require "../model"

module Ktistec
  module Model
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
