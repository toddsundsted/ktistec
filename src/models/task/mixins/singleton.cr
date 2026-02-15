class Task
  # A singleton class.
  #
  # Only a single active instance of this class is meant to exist.
  #
  # An active instance may be either running or runnable. Complete or
  # failed tasks may remain in the database for forensic purposes and
  # are not considered active.
  #
  module Singleton
    macro included
      @source_iri = ""
      @subject_iri  = ""

      # Finds the active instance.
      #
      # Returns `nil` if no active instance exists.
      #
      def self.find_active : self?
        query = <<-SQL
          SELECT #{{{@type}}.columns}
          FROM tasks
          WHERE type = ?
            AND complete = 0
            AND backtrace IS NULL
          ORDER BY id DESC
          LIMIT 1
        SQL
        {{@type}}.query_all(query, {{@type}}.name).first?
      end

      # Returns the current active instance of this singleton task.
      #
      # Creates and saves a new instance if no active instance exists.
      #
      def self.current_instance : self
        find_active || {{@type}}.new.save
      end

      # Ensures the singleton task is scheduled.
      #
      # Typically called on server startup to ensure singleton tasks
      # are created and scheduled.
      #
      def self.ensure_scheduled
        instance = current_instance
        instance.schedule if instance.runnable? && instance.next_attempt_at.nil?
        instance
      end
    end
  end
end
