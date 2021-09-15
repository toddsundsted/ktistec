require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE tasks (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "type" varchar(63) NOT NULL,
      "source_iri" text COLLATE NOCASE,
      "subject_iri" text COLLATE NOCASE,
      "failures" text,
      "running" boolean DEFAULT 0,
      "complete" boolean DEFAULT 0,
      "backtrace" text,
      "next_attempt_at" datetime,
      "last_attempt_at" datetime,
      "state" text
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_tasks_type
      ON tasks (type ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_tasks_type_running_complete_backtrace_next_attempt_at_created_at
      ON tasks (type ASC, running ASC, complete ASC, backtrace ASC, next_attempt_at ASC, created_at ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE tasks
  STR
end
