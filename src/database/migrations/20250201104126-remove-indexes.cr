require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_sessions_account_id
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_sessions_updated_at
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_username
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_objects_published
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_activities_target_iri
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_sessions_account_id
      ON sessions (account_id ASC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_sessions_updated_at
      ON sessions (updated_at DESC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_actors_username
      ON actors (username ASC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_objects_published
      ON objects (published ASC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_activities_target_iri
      ON activities (target_iri ASC)
  STR
end
