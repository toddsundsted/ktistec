require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE tasks (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "type" varchar(63) NOT NULL,
      "source_iri" text,
      "subject_iri" text,
      "failures" text
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_tasks_type
      ON tasks (type ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE tasks;
  STR
end
