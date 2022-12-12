require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_iri
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_actors_iri
      ON actors (iri ASC)
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_objects_iri
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_objects_iri
      ON objects (iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_iri
  STR
  db.exec <<-STR
    CREATE INDEX idx_actors_iri
      ON actors (iri ASC)
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_objects_iri
  STR
  db.exec <<-STR
    CREATE INDEX idx_objects_iri
      ON objects (iri ASC)
  STR
end
