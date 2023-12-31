require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
   CREATE INDEX idx_tasks_subject_iri
     ON tasks (subject_iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_tasks_subject_iri
  STR
end
