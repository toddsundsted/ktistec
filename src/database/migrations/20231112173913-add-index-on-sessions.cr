require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_sessions_updated_at ON sessions (updated_at DESC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_sessions_updated_at
  STR
end
