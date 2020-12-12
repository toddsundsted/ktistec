require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE activities (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "type" varchar(63) NOT NULL,
      "iri" varchar(255) NOT NULL,
      "visible" boolean,
      "published" datetime,
      "actor_iri" text,
      "object_iri" text,
      "target_iri" text,
      "to" text,
      "cc" text,
      "summary" text
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_activities_iri
      ON activities (iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_activities_object_iri
      ON activities (object_iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE activities;
  STR
end
