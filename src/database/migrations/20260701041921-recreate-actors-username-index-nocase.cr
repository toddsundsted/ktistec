require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_username
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_actors_username
      ON actors (username COLLATE NOCASE ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_username
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_actors_username
      ON actors (username ASC)
  STR
end
