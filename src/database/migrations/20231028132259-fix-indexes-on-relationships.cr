require "../../framework/database"

extend Ktistec::Database::Migration

# Historical Note: This migration did the wrong thing. It was
# introduced to improve a slow query (the followed tag relationship)
# on the notifications page, but reduced the performance of the
# notifications query itself, as well as other similar queries
# (timeline, inbox, etc.) ordered by `created_at`. Both indexes are
# required!

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_type_from_iri_created_at ON relationships (type ASC, from_iri ASC, created_at DESC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_from_iri_created_at_type
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_type_to_iri ON relationships (type ASC, to_iri ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_to_iri_type
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri_created_at_type ON relationships (from_iri ASC, created_at DESC, type ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_type_from_iri_created_at
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_to_iri_type ON relationships (to_iri ASC, type ASC)
  STR
  db.exec <<-STR
    DROP INDEX idx_relationships_type_to_iri
  STR
end
