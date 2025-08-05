require "../task"
require "./mixins/singleton"
require "benchmark"

class Task
  # Garbage collection task for ActivityPub objects.
  #
  # Garbage collection identifies and removes objects that are not
  # connected to the user through preservation rules, described below.
  #
  # ## How It Works
  #
  # 1. **Identification**: Identifies objects that should be preserved
  #    based on preservation rules, described below.
  #
  # 2. **Deletion**: Deletes objects and all associated records (tags,
  #    activities, relationships, translations).
  #
  # 3. **Optimization**: Runs SQLite VACUUM and OPTIMIZE to reclaim
  #    freed space.
  #
  # ## Preservation Rules
  #
  # Objects are preserved if they meet any of the following criteria:
  #
  # - Objects attributed to local users or to remote actors that local
  #   users follow
  #
  # - Objects associated with activities created by local users or by
  #   remote actors that local users follow
  #
  # - Objects with hashtags, mentions, or that are part of threads
  #   that local users follow
  #
  # - Objects in relationships with local users (timelines,
  # - notifications, the outbox)
  #
  # - Objects in a thread (unless every object in the thread can be
  # - deleted)
  #
  # - Recent objects
  #
  # ## Of Note
  #
  # - Deleting an object will remove many associated records
  #   (activities, relationships, tags, translations), but never
  #   other objects.
  #
  # - Either entire threads are preserved or they are eligible for
  #   deletion.
  #
  class CollectGarbage < Task
    include Singleton

    Log = ::Log.for(self)

    DEFAULT_MAX_AGE_DAYS = 365
    DEFAULT_MAX_DELETE_COUNT = 1000

    class_property get_max_age_days : Int32 do
      ENV.fetch("CLEANUP_MAX_AGE_DAYS", DEFAULT_MAX_AGE_DAYS.to_s).to_i
    end

    class_property get_max_delete_count : Int32 do
      ENV.fetch("CLEANUP_MAX_DELETE_COUNT", DEFAULT_MAX_DELETE_COUNT.to_s).to_i
    end

    # Performs garbage collection when scheduled.
    #
    def perform(
         max_age_days = self.class.get_max_age_days,
         max_delete_count = self.class.get_max_delete_count
       )
      Log.info { "Starting garbage collection of objects older than #{max_age_days} days (maximum #{max_delete_count} objects)" }

      deleted_count = garbage_collect_objects(max_delete_count)

      Log.info { "Garbage collection completed: deleted #{deleted_count} objects" }

      optimize_database

      deleted_count
    ensure
      self.next_attempt_at = 1.day.from_now
    end

    # Performs garbage collection on-demand.
    #
    def perform_on_demand(
         max_age_days = self.class.get_max_age_days,
         max_delete_count = Int32::MAX
       )
      Log.info { "Starting garbage collection of objects older than #{max_age_days} days" }

      deleted_count = garbage_collect_objects(max_delete_count)

      Log.info { "Garbage collection completed: deleted #{deleted_count} objects" }

      optimize_database

      deleted_count
    ensure
      self.next_attempt_at = 1.day.from_now
    end

    private def optimize_database
      unless Kemal.config.env == "test"
        time = Benchmark.realtime do
          Ktistec.database.exec("VACUUM")
          # see: https://sqlite.org/lang_analyze.html#automatically_running_analyze
          Ktistec.database.exec("PRAGMA optimize=0x10002")
        end
        Log.info { "Database optimization completed in #{time.total_seconds.round(2)} seconds" }
      end
    end

    private def garbage_collect_objects(max_delete_count : Int32)
      objects_to_delete = [] of String
      time = Benchmark.realtime do
        objects_to_delete = get_objects_for_deletion(max_delete_count)
      end
      Log.info { "Object identification completed in #{time.total_seconds.round(2)} seconds" }

      return 0 if objects_to_delete.empty?

      batch_number = 1
      deleted_count = 0
      Log.info { "Found #{objects_to_delete.size} objects to delete" }
      objects_to_delete.each_slice(100) do |batch|
        Log.info { "Processing batch #{batch_number} (#{batch.size} objects)" }
        time = Benchmark.realtime do
          batch.each do |object_iri|
            deleted_count += delete_object_and_associations(object_iri)
          end
        end
        Log.info { "Batch #{batch_number} completed in #{time.total_seconds.round(2)} seconds" }
        batch_number += 1
      end

      deleted_count
    end

    def self.followed_or_following_actors
      <<-SQL
      SELECT DISTINCT to_iri as actor_iri FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      WHERE r.type = 'Relationship::Social::Follow'
      UNION
      SELECT DISTINCT from_iri as actor_iri FROM relationships r
      JOIN accounts ua ON r.to_iri = ua.iri
      WHERE r.type = 'Relationship::Social::Follow'
      SQL
    end

    def self.objects_attributed_to_user
      <<-SQL
      SELECT o.iri FROM objects o
      JOIN accounts ua ON o.attributed_to_iri = ua.iri
      SQL
    end

    def self.objects_attributed_to_followed_actors
      <<-SQL
      SELECT DISTINCT o.iri FROM objects o
      JOIN followed_or_following_actors ff ON o.attributed_to_iri = ff.actor_iri
      SQL
    end

    def self.objects_associated_with_user_activities
      <<-SQL
      SELECT DISTINCT object_iri AS iri FROM activities a
      JOIN accounts ua ON a.actor_iri = ua.iri
      WHERE object_iri IS NOT NULL
      UNION
      SELECT DISTINCT target_iri AS iri FROM activities a
      JOIN accounts ua ON a.actor_iri = ua.iri
      WHERE target_iri IS NOT NULL
      SQL
    end

    def self.objects_associated_with_followed_actor_activities
      <<-SQL
      SELECT DISTINCT object_iri AS iri FROM activities a
      JOIN followed_or_following_actors ff ON a.actor_iri = ff.actor_iri
      WHERE object_iri IS NOT NULL
      UNION
      SELECT DISTINCT target_iri AS iri FROM activities a
      JOIN followed_or_following_actors ff ON a.actor_iri = ff.actor_iri
      WHERE target_iri IS NOT NULL
      SQL
    end

    def self.followed_hashtags
      <<-SQL
      SELECT DISTINCT to_iri as hashtag_name FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      WHERE r.type = 'Relationship::Content::Follow::Hashtag'
      SQL
    end

    def self.followed_mentions
      <<-SQL
      SELECT DISTINCT to_iri as mention_href FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      WHERE r.type = 'Relationship::Content::Follow::Mention'
      SQL
    end

    def self.followed_threads
      <<-SQL
      SELECT DISTINCT to_iri as thread_iri FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      WHERE r.type = 'Relationship::Content::Follow::Thread'
      SQL
    end

    # NOTE: this use of "thread" is okay, because if a thread is
    # followed (or fetched), its objects have been migrated as part of
    # the process.

    def self.objects_associated_with_followed_content
      <<-SQL
      SELECT DISTINCT t.subject_iri AS iri FROM tags t
      JOIN followed_hashtags fh ON t.name = fh.hashtag_name
      WHERE t.type = 'Tag::Hashtag'
      UNION
      SELECT DISTINCT t.subject_iri AS iri FROM tags t
      JOIN followed_mentions fm ON t.href = fm.mention_href
      WHERE t.type = 'Tag::Mention'
      UNION
      SELECT DISTINCT o.iri FROM objects o
      JOIN followed_threads ft ON o.thread = ft.thread_iri
      SQL
    end

    def self.objects_in_user_relationships
      <<-SQL
      SELECT DISTINCT r.to_iri AS iri FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      WHERE r.type != 'Relationship::Content::Inbox'
      UNION
      SELECT DISTINCT a.object_iri AS iri FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      JOIN activities a ON a.iri = r.to_iri
      WHERE r.type != 'Relationship::Content::Inbox'
        AND a.object_iri IS NOT NULL
      UNION
      SELECT DISTINCT a.target_iri AS iri FROM relationships r
      JOIN accounts ua ON r.from_iri = ua.iri
      JOIN activities a ON a.iri = r.to_iri
      WHERE r.type != 'Relationship::Content::Inbox'
        AND a.target_iri IS NOT NULL
      SQL
    end

    def self.objects_too_recent_to_delete
      <<-SQL
      SELECT o.iri FROM objects o
      WHERE o.created_at >= datetime('now', '-#{get_max_age_days} days')
      SQL
    end

    def self.objects_to_preserve
      <<-SQL
      #{objects_attributed_to_user}
      UNION
      #{objects_attributed_to_followed_actors}
      UNION
      #{objects_associated_with_user_activities}
      UNION
      #{objects_associated_with_followed_actor_activities}
      UNION
      #{objects_associated_with_followed_content}
      UNION
      #{objects_in_user_relationships}
      UNION
      #{objects_too_recent_to_delete}
      SQL
    end

    # Finds all objects that are part of the same thread as any
    # preserved object.
    #
    # Uses the "thread" column when available; falls back to the
    # "in_reply_to_iri" column for legacy threads.
    #
    def self.objects_in_threads
      <<-SQL
      SELECT DISTINCT o.iri FROM objects o
      WHERE
        -- objects in modern threads
        (o.thread IS NOT NULL
         AND o.thread IN (
           SELECT DISTINCT p.thread FROM objects p
            WHERE p.thread IS NOT NULL
              AND p.iri IN (#{objects_to_preserve})
         ))
        OR
        -- objects in legacy threads. find root and traverse
        (o.thread IS NULL
         AND o.iri IN (
           -- find common root
           WITH RECURSIVE reply_chain(iri, root_iri) AS (
             -- objects that aren't replies (roots)
             SELECT o1.iri, o1.iri as root_iri
               FROM objects o1
              WHERE o1.thread IS NULL AND o1.in_reply_to_iri IS NULL
             UNION
             -- recursive case: objects that are replies
             SELECT o2.iri, rc.root_iri
               FROM objects o2, reply_chain rc
              WHERE o2.thread IS NULL AND o2.in_reply_to_iri = rc.iri
           )
           SELECT DISTINCT rc.iri
             FROM reply_chain rc
            WHERE rc.root_iri IN (
             SELECT DISTINCT rc2.root_iri
               FROM reply_chain rc2
              WHERE rc2.iri IN (#{objects_to_preserve})
           )
         ))
      SQL
    end

    private def get_objects_for_deletion(maximum : Int32)
      query = <<-SQL
      WITH
      followed_or_following_actors AS (
        #{self.class.followed_or_following_actors}
      ),
      followed_hashtags AS (
        #{self.class.followed_hashtags}
      ),
      followed_mentions AS (
        #{self.class.followed_mentions}
      ),
      followed_threads AS (
        #{self.class.followed_threads}
      ),
      objects_to_preserve AS (
        #{self.class.objects_to_preserve}
        UNION
        #{self.class.objects_in_threads}
      )
      SELECT o.iri FROM objects o
      LEFT JOIN objects_to_preserve otp ON o.iri = otp.iri
      WHERE otp.iri IS NULL
      ORDER BY o.created_at ASC
      LIMIT ?
      SQL

      Ktistec.database.query_all(query, maximum, as: String)
    end

    # Deletes an object and associated records.
    #
    # This method deletes the object and all records (except other
    # objects via the `in_reply_to` association) that reference that
    # object.
    #
    # Returns the number of objects deleted.
    #
    # ## Parameters
    #
    # - `object_iri` - The IRI of the object to delete
    #
    def delete_object_and_associations(object_iri : String)
      Ktistec.database.exec("DELETE FROM tags WHERE subject_iri = ?", object_iri)

      Ktistec.database.exec("DELETE FROM translations WHERE origin_id IN (SELECT id FROM objects WHERE iri = ?)", object_iri)

      Ktistec.database.exec("DELETE FROM relationships WHERE from_iri = ?", object_iri)
      Ktistec.database.exec("DELETE FROM relationships WHERE to_iri = ?", object_iri)

      Ktistec.database.exec("DELETE FROM relationships WHERE to_iri IN (SELECT iri FROM activities WHERE object_iri = ? OR target_iri = ?)", object_iri, object_iri)
      Ktistec.database.exec("DELETE FROM relationships WHERE from_iri IN (SELECT iri FROM activities WHERE object_iri = ? OR target_iri = ?)", object_iri, object_iri)

      Ktistec.database.exec("DELETE FROM activities WHERE object_iri IN (SELECT iri FROM activities WHERE object_iri = ? OR target_iri = ?)", object_iri, object_iri)

      Ktistec.database.exec("DELETE FROM activities WHERE object_iri = ?", object_iri)
      Ktistec.database.exec("DELETE FROM activities WHERE target_iri = ?", object_iri)

      result = Ktistec.database.exec("DELETE FROM objects WHERE iri = ?", object_iri)

      result.rows_affected.to_i
    end
  end
end
