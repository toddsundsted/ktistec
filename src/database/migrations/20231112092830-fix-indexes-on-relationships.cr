require "../../framework/database"

extend Ktistec::Database::Migration

# Historical Note: Reintroduces indexes that were removed in the
# previous migration.

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri_created_at_type ON relationships (from_iri ASC, created_at DESC, type ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_to_iri_type ON relationships (to_iri ASC, type ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_relationships_from_iri_created_at_type
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_to_iri_type
  STR
end
