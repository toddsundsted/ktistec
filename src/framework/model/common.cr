require "../model"

module Balloon
  module Model
    module Common
      @[Persistent]
      @[Insignificant]
      property created_at : Time

      @[Persistent]
      @[Insignificant]
      property updated_at : Time
    end
  end
end

module Common
end
