require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_activities_target_iri ON activities (target_iri ASC)
  STR

  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri_type ON relationships (from_iri ASC, type ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_activities_target_iri
  STR

  db.exec <<-STR
    DROP INDEX idx_relationships_from_iri_type
  STR
end
