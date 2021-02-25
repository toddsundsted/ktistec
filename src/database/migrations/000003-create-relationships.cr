require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE relationships (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      type varchar(63) NOT NULL,
      from_iri varchar(255) NOT NULL COLLATE NOCASE,
      to_iri varchar(255) NOT NULL COLLATE NOCASE,
      confirmed boolean,
      visible boolean
    )
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_from_iri
      ON relationships (from_iri ASC, type ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_relationships_to_iri
      ON relationships (to_iri ASC, type ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE relationships;
  STR
end
