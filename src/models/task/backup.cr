require "benchmark"

require "../task"
require "./mixins/singleton"

class Task
  # Creates a database backup.
  #
  class Backup < Task
    include Singleton

    Log = ::Log.for(self)

    def perform
      if Kemal.config.env == "production"
        perform_backup
      end
    end

    def perform_backup
      name = Ktistec.db_file
      date = Time.local.to_s("%Y%m%d")
      backup = "#{name}.backup_#{date}"

      Log.trace { "database backup beginning" }

      times = Benchmark.measure("backup times") do
        DB.open(backup) do |db_backup|
          db_backup.using_connection do |conn_backup|
            Ktistec.database.using_connection do |conn_db|
              conn_db.dump(conn_backup)
            end
          end
        end
      end

      Log.trace { "#{times.label}: #{times.to_s}" }
    ensure
      self.next_attempt_at = 1.day.from_now
    end
  end
end
