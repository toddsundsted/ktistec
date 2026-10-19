require "../../../src/services/feed/judges"

class Feed
  module Judges
    # Unregisters every judge.
    #
    def clear! : Nil
      @@registered.each_key { |name| Backend.unregister(name) }
      @@registered.clear
    end
  end
end
