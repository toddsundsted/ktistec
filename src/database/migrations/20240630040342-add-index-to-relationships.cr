require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_created_at
      ON relationships (created_at DESC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_relationships_created_at
  STR
end
