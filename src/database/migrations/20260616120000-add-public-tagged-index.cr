require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_relationships_public_tagged_from_iri_created_at
      ON relationships (from_iri ASC, created_at ASC)
      WHERE type = 'Relationship::Content::PublicTagged'
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_relationships_public_tagged_from_iri_created_at
  STR
end
