require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_objects_attributed_to_iri
      ON objects (attributed_to_iri ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_objects_attributed_to_iri
  STR
end
