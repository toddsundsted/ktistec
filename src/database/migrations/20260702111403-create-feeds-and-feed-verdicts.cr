require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE feeds (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "owner_iri" varchar(255) NOT NULL COLLATE NOCASE,
      "name" varchar(255) NOT NULL,
      "backend" varchar(63) NOT NULL,
      "version" integer NOT NULL DEFAULT 1,
      "description" text,
      "examples" text,
      "params" text
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_feeds_owner_iri
      ON feeds (owner_iri ASC)
  STR
  db.exec <<-STR
    CREATE TABLE feed_verdicts (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "feed_id" integer,
      "object_iri" varchar(255) NOT NULL COLLATE NOCASE,
      "included" boolean NOT NULL,
      "reason" text,
      "version" integer NOT NULL,
      "position" datetime NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_feed_verdicts_feed_id_object_iri
      ON feed_verdicts (feed_id ASC, object_iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DELETE FROM relationships WHERE type LIKE 'Feed::%'
  STR
  db.exec <<-STR
    DROP TABLE feed_verdicts
  STR
  db.exec <<-STR
    DROP TABLE feeds
  STR
end
