class Task
  # A singleton class.
  #
  # Only a single instance of this class is meant to exist.
  #
  module Singleton
    macro included
      @source_iri = ""
      @subject_iri  = ""

      class_property instance : self { self.all.first? || self.new.save }

      def self.schedule_unless_exists
        if !instance.running && !instance.complete && instance.backtrace.nil?
          instance.schedule
        end
      end
    end
  end
end
