class Task
  # A singleton class.
  #
  # Only a single instance of this class is meant to exist.
  #
  module Singleton
    macro included
      @source_iri = ""
      @subject_iri  = ""

      def self.schedule_unless_exists
        if self.where("running = 0 AND complete = 0 AND backtrace IS NULL").empty?
          self.new.schedule
        end
      end
    end
  end
end
