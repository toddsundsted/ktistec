require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE filter_terms (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "actor_id" integer,
      "term" text NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_filter_terms_actor_id
      ON filter_terms (actor_id ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE filter_terms
  STR
end
