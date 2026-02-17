require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_activities_instrument_iri
      ON activities (instrument_iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_activities_instrument_iri
  STR
end
