require "../model"

module Balloon
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

module Common
end
