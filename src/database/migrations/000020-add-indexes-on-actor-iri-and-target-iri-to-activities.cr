require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_activities_actor_iri
      ON activities (actor_iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_activities_target_iri
      ON activities (target_iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_activities_actor_iri
  STR
  db.exec <<-STR
    DROP INDEX idx_activities_target_iri
  STR
end
