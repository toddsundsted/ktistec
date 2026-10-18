require "../../../src/services/feed/judges"

class Feed
  module Judges
    # Unregisters every judge.
    #
    def clear! : Nil
      @@registered.each { |name| Backend.unregister(name) }
      @@registered.clear
    end
  end
end
