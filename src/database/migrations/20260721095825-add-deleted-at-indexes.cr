require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_objects_deleted_at_iri
      ON objects (deleted_at ASC, iri ASC)
      WHERE deleted_at IS NOT NULL
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_actors_deleted_at_iri
      ON actors (deleted_at ASC, iri ASC)
      WHERE deleted_at IS NOT NULL
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_objects_deleted_at_iri
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_deleted_at_iri
  STR
end
