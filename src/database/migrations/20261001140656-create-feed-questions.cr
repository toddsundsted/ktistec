require "json"

require "../../framework/database"

extend Ktistec::Database::Migration

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
  db.using_connection do |connection|
    connection.exec <<-STR
      CREATE TEMP TABLE backfills (
        "subject_iri" text NOT NULL,
        "floor_id" integer,
        "cursor" integer
      )
    STR
    query = "SELECT subject_iri, state FROM tasks WHERE type = 'Task::BackfillFeed' AND complete = 0"
    connection.query_all(query, as: {String, String?}).each do |subject_iri, state|
      progress = state.try { |json| JSON.parse(json).as_h? }
      floor_id = progress.try(&.["floor_id"]?).try(&.as_i64?)
      cursor = progress.try(&.["cursor"]?).try(&.as_i64?)
      connection.exec("INSERT INTO backfills VALUES (?, ?, ?)", subject_iri, floor_id, cursor)
    end
    connection.exec <<-STR
      INSERT OR IGNORE INTO feed_questions (created_at, updated_at, version_id, object_iri, live, due_at, batched)
      SELECT datetime('now'), datetime('now'), c.version_id, c.iri, 0, datetime('now'), 0
        FROM (
          SELECT f.version_id, o.iri, o.id, ROW_NUMBER() OVER (PARTITION BY f.id ORDER BY o.id DESC) AS rank
            -- `CROSS JOIN` pins the join order to backfills, feeds, objects
            FROM backfills t
            CROSS JOIN feeds f
              ON t.subject_iri = f.owner_iri || '/feeds/' || f.id
            CROSS JOIN objects o
              -- copied from `Task::BackfillFeed#perform` and `Feed::Candidates.floor_id`
              ON o.id > COALESCE(
                   t.floor_id,
                   (SELECT id FROM objects WHERE created_at <= f.floor ORDER BY id DESC LIMIT 1),
                   0
                 )
             AND o.id < COALESCE(t.cursor, 9223372036854775807)
              -- end of copy
           WHERE f.version_id IS NOT NULL
             AND f.draft = 0
             AND f.floor IS NOT NULL
             -- copied from `Rules::View::Feed::CANDIDATE_SQL`
             AND o.published IS NOT NULL
             AND o.special IS NULL
             AND (
               o.visible = 1
               OR EXISTS (
                 SELECT 1
                   FROM relationships m
                   JOIN activities a ON a.iri = m.to_iri
                  WHERE m.type IN ('Relationship::Content::Inbox', 'Relationship::Content::Outbox')
                    AND m.from_iri = f.owner_iri
                    AND a.object_iri = o.iri
                    AND a.undone_at IS NULL
               )
             )
             -- end of copy
             -- copied from `Feed::Candidates::CANDIDATES_SQL`
             AND NOT EXISTS (
               SELECT 1
                 FROM feed_verdicts v
                WHERE v.version_id = f.version_id
                  AND v.object_iri = o.iri
             )
             -- end of copy
        ) c
       ORDER BY c.rank ASC, c.id DESC
       -- copied from `Feed::Queue.backfill_cap`
       LIMIT 100000
       -- end of copy
    STR
    connection.exec("DROP TABLE backfills")
  end
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
           FROM feed_questions q
          WHERE q.version_id = f.version_id
       )
  STR
  db.exec <<-STR
    DROP TABLE feed_questions
  STR
end
