require "../../framework/database"

extend Ktistec::Database::Migration

# a backfill task that is not complete is evidence of a backfill in
# progress, so its feed is backfilled again. a published feed with no
# such task is taken to be backfilled, so its version is covered from
# its floor up.

private ONGOING = <<-STR
  EXISTS (
    SELECT 1
      FROM tasks t
     WHERE t.type = 'Task::BackfillFeed'
       AND t.complete = 0
       AND t.subject_iri = f.owner_iri || '/feeds/' || f.id
  )
STR

up do |db|
  db.exec <<-STR
    CREATE TABLE feed_questions (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "version_id" integer NOT NULL,
      "object_iri" varchar(255) NOT NULL COLLATE NOCASE,
      "live" boolean NOT NULL,
      "due_at" datetime NOT NULL,
      "batched" boolean NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_feed_questions_version_id_object_iri
      ON feed_questions (version_id ASC, object_iri ASC)
      WHERE batched = 0
  STR
  db.exec <<-STR
    CREATE INDEX idx_feed_questions_batched_live_due_at
      ON feed_questions (batched ASC, live DESC, due_at ASC)
  STR
  db.exec <<-STR
    UPDATE feed_versions
       SET backfill_cursor = (
             SELECT MIN(COALESCE(
                      -- copied from `Feed::Candidates.floor_id`
                      (SELECT o.id FROM objects o WHERE o.created_at <= f.floor ORDER BY o.id DESC LIMIT 1),
                      -- end of copy
                      0
                    ))
               FROM feeds f
              WHERE f.version_id = feed_versions.id
                AND f.draft = 0
                AND f.floor IS NOT NULL
                AND NOT #{ONGOING}
           )
     WHERE EXISTS (
       SELECT 1
         FROM feeds f
        WHERE f.version_id = feed_versions.id
          AND f.draft = 0
          AND f.floor IS NOT NULL
          AND NOT #{ONGOING}
     )
  STR
  db.exec <<-STR
    INSERT INTO tasks (created_at, updated_at, type, source_iri, subject_iri, running, complete, next_attempt_at)
    SELECT datetime('now'), datetime('now'), 'Task::Feed::EnqueueBackfill', f.owner_iri,
           CAST(f.id AS TEXT),
           0, 0, datetime('now')
      FROM feeds f
     WHERE f.draft = 0
       AND f.floor IS NOT NULL
       AND #{ONGOING}
  STR
  db.exec <<-STR
    DELETE FROM tasks
     WHERE type = 'Task::BackfillFeed'
  STR
end

down do |db|
  db.exec <<-STR
    -- copied from `20260825140851-rebuild-feeds-on-the-object-clock.cr`
    INSERT INTO tasks (created_at, updated_at, type, source_iri, subject_iri, running, complete, next_attempt_at)
    SELECT datetime('now'), datetime('now'), 'Task::BackfillFeed', f.owner_iri,
           f.owner_iri || '/feeds/' || f.id,
           0, 0, datetime('now')
      FROM feeds f
     WHERE f.draft = 0
       AND f.floor IS NOT NULL
    -- end of copy
       AND EXISTS (
         SELECT 1
           FROM tasks t
          WHERE t.type = 'Task::Feed::EnqueueBackfill'
            AND t.complete = 0
            AND t.subject_iri = CAST(f.id AS TEXT)
       )
  STR
  db.exec <<-STR
    DELETE FROM tasks
     WHERE type = 'Task::Feed::EnqueueBackfill'
  STR
  db.exec <<-STR
    UPDATE feed_versions
       SET backfill_cursor = NULL
  STR
  db.exec <<-STR
    DROP TABLE feed_questions
  STR
end
