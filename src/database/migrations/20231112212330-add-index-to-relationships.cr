require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE INDEX idx_relationships_type_id ON relationships (type ASC, id ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX idx_relationships_type_id
  STR
end
