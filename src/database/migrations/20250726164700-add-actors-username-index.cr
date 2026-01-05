require "../../framework/database"

extend Ktistec::Database::Migration

# This index is used by the query in `self.match?` that is itself used
# by `Ktistec::HTML.enhance` to find actors for mentions.

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_actors_username
      ON actors (username ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_actors_username
  STR
end
