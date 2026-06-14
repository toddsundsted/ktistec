require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_relationships_public_timeline_created_at
      ON relationships (created_at ASC)
      WHERE type = 'Relationship::Content::PublicTimeline'
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_relationships_public_timeline_created_at
  STR
end
