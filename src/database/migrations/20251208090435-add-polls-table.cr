require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE polls (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "question_iri" varchar(255) NOT NULL,
      "options" text NOT NULL,
      "multiple_choice" integer NOT NULL DEFAULT 0,
      "voters_count" integer,
      "closed_at" datetime,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_polls_question_iri
      ON polls (question_iri)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE polls
  STR
end
