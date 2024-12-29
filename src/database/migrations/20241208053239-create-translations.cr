require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE translations (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "origin_id" integer,
      "summary" text,
      "content" text,
      "name" text
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_translations_origin_id
      ON translations (origin_id ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE translations
  STR
end
