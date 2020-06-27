require "../../framework/database"

extend Balloon::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE objects (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "type" varchar(63) NOT NULL,
      "iri" varchar(255) NOT NULL,
      "visible" boolean,
      "published" datetime,
      "in_reply_to" text,
      "replies" text,
      "attributed_to" text,
      "to" text,
      "cc" text,
      "summary" text,
      "content" text,
      "media_type" text,
      "source" text,
      "attachments" text,
      "urls" text
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_objects_iri
      ON objects (iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_objects_in_reply_to_published
      ON objects (in_reply_to ASC, published ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE objects;
  STR
end
