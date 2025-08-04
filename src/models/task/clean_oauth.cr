require "../task"
require "./mixins/singleton"

class Task
  # Cleans up OAuth data.
  #
  # Cleans up expired access tokens and orphaned clients.
  #
  class CleanOauth < Task
    include Singleton

    Log = ::Log.for(self)

    def perform
      Log.info { "Starting OAuth cleanup" }
      cleanup_expired_tokens
      cleanup_orphaned_clients
    ensure
      random_delay = (rand(3600) - 1800).seconds
      self.next_attempt_at = 1.day.from_now + random_delay
    end

    private def cleanup_expired_tokens
      result = Ktistec.database.exec(
        <<-SQL
        DELETE FROM oauth_access_tokens
         WHERE expires_at < datetime('now')
        SQL
      )
      deleted_count = result.rows_affected.to_i
      Log.info { "Deleted #{deleted_count} expired access tokens" }
      deleted_count
    end

    private def cleanup_orphaned_clients
      result = Ktistec.database.exec(
        <<-SQL
        DELETE FROM oauth_clients
         WHERE created_at < datetime('now', '-1 hour')
           AND id NOT IN (
          SELECT DISTINCT client_id
            FROM oauth_access_tokens
           WHERE expires_at >= datetime('now')
        )
        SQL
      )
      deleted_count = result.rows_affected.to_i
      Log.info { "Deleted #{deleted_count} orphaned OAuth clients" }
      deleted_count
    end
  end
end
