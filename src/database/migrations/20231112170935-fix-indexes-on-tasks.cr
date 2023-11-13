require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_tasks_running_complete_backtrace ON tasks (running ASC, complete ASC, backtrace ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_tasks_type_running_complete_backtrace_next_attempt_at_created_at
  STR
  db.exec <<-STR
    CREATE INDEX idx_tasks_created_at ON tasks (created_at DESC)
  STR
  db.exec <<-STR
    DROP INDEX idx_tasks_type
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX idx_tasks_type_running_complete_backtrace_next_attempt_at_created_at ON tasks (type ASC, running ASC, complete ASC, backtrace ASC, next_attempt_at ASC, created_at ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_tasks_running_complete_backtrace
  STR
  db.exec <<-STR
    CREATE INDEX idx_tasks_type ON tasks (type ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_tasks_created_at
  STR
end
