require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DROP INDEX idx_tasks_created_at
  STR
  db.exec <<-STR
    ANALYZE relationships
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX idx_tasks_created_at ON tasks (created_at DESC)
  STR
  db.exec <<-STR
    ANALYZE relationships
  STR
end
