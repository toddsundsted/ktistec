require "../task"
require "./mixins/singleton"

class Task
  # Cleans up OAuth data.
  #
  # This task implements the following cleanup rules:
  #
  # **Expired Access Tokens**:
  # 1. Delete access tokens where "expires_at < current_time"
  #
  # **Inactive Clients**:
  # Note: Manually created clients are always preserved.
  # 1. Delete clients created more than 1 month ago AND never accessed
  # 2. Delete clients that were last accessed more than one year ago
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
         WHERE manual = 0
           AND (
             (last_accessed_at IS NULL AND created_at < datetime('now', '-1 month'))
              OR
             (last_accessed_at < datetime('now', '-1 year'))
           )
        SQL
      )
      deleted_count = result.rows_affected.to_i
      Log.info { "Deleted #{deleted_count} inactive clients" }
      deleted_count
    end
  end
end
