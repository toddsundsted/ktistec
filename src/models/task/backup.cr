require "benchmark"

require "../task"

class Task
  # Creates a database backup.
  #
  class Backup < Task
    def initialize(*args, **opts)
      self.source_iri = ""
      self.subject_iri = ""
      super(*args, **opts)
    end

    def self.schedule_unless_exists
      if self.where("running = 0 AND complete = 0 AND backtrace IS NULL").empty?
        self.new.schedule
      end
    end

    def perform
      name = Ktistec.db_file
      date = Time.local.to_s("%Y%m%d")
      backup = "#{name}.backup_#{date}"

      Log.info { "database backup beginning" }

      times = Benchmark.measure("backup times") do
        DB.open(backup) do |db_backup|
          db_backup.using_connection do |conn_backup|
            Ktistec.database.using_connection do |conn_db|
              conn_db.dump(conn_backup)
            end
          end
        end
      end

      Log.info { "#{times.label}: #{times.to_s}" }
    ensure
      self.next_attempt_at = 1.day.from_now
    end
  end
end
