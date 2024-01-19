require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DROP INDEX idx_relationships_type_from_iri_created_at
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_type_to_iri
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_from_iri_created_at_type
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_to_iri_type
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_type_id
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_type ON relationships (type ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_to_iri ON relationships (to_iri ASC)
  STR
  db.exec <<-STR
    ANALYZE relationships
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_type_from_iri_created_at ON relationships (type ASC, from_iri ASC, created_at DESC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_type_to_iri ON relationships (type ASC, to_iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri_created_at_type ON relationships (from_iri ASC, created_at DESC, type ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_to_iri_type ON relationships (to_iri ASC, type ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_type_id ON relationships (type ASC, id ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_type
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_to_iri
  STR
  db.exec <<-STR
    ANALYZE relationships
  STR
end
