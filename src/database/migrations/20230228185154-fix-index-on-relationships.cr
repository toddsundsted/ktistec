require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri_created_at_type ON relationships (from_iri ASC, created_at DESC, type ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_from_iri_type_created_at
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri_type_created_at ON relationships (from_iri ASC, type ASC, created_at DESC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_from_iri_created_at_type
  STR
end
