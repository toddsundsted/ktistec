require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_objects_attributed_to_iri_published_id
      ON objects (attributed_to_iri ASC, published DESC, id DESC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_objects_attributed_to_iri_published_id
  STR
end
