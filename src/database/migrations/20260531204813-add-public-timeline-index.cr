require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE UNIQUE INDEX IF NOT EXISTS idx_relationships_public_timeline_to_iri
      ON relationships (to_iri ASC)
      WHERE type = 'Relationship::Content::PublicTimeline'
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_relationships_public_timeline_to_iri
  STR
end
