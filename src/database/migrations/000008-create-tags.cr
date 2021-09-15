require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE tags (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "subject_iri" text NOT NULL COLLATE NOCASE,
      "type" varchar(99) NOT NULL,
      "name" varchar(99) NOT NULL COLLATE NOCASE,
      "href" text
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_tags_type_subject_iri
      ON tags (type ASC, subject_iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_tags_type_name
      ON tags (type ASC, name ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE tags
  STR
end
