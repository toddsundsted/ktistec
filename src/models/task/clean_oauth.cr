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
      # ±30 minutes on 1 day = 1800 seconds / 86400 seconds ≈ 0.0208 (2.08%)
      self.next_attempt_at = randomized_next_attempt_at(1.day, randomization_percentage: 0.0208)
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
