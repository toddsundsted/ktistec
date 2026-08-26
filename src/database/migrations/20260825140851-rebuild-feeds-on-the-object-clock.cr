require "../../framework/database"

extend Ktistec::Database::Migration

# feed verdict positions predate the object clock. delete every feed's
# verdicts and materialized rows and schedule a backfill per published
# feed.

up do |db|
  db.exec <<-STR
    UPDATE feeds
       SET floor = datetime(created_at, '-30 days')
     WHERE floor IS NULL
  STR
  db.exec <<-STR
    DELETE FROM feed_verdicts
  STR
  db.exec <<-STR
    DELETE FROM relationships
     WHERE type LIKE 'Feed::%'
  STR
  db.exec <<-STR
    DELETE FROM tasks
     WHERE type = 'Task::BackfillFeed'
       AND complete = 0
       AND backtrace IS NULL
  STR
  db.exec <<-STR
    INSERT INTO tasks (created_at, updated_at, type, source_iri, subject_iri, running, complete, next_attempt_at)
    SELECT datetime('now'), datetime('now'), 'Task::BackfillFeed', f.owner_iri,
           f.owner_iri || '/feeds/' || f.id,
           0, 0, datetime('now')
      FROM feeds f
     WHERE f.draft = 0
  STR
end

down do |db|
  db.exec <<-STR
    DELETE FROM tasks
     WHERE type = 'Task::BackfillFeed'
       AND complete = 0
       AND backtrace IS NULL
  STR
end
