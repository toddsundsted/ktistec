require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE tag_statistics (
      "type" varchar(99) NOT NULL,
      "name" varchar(99) NOT NULL COLLATE NOCASE,
      "count" integer,
      PRIMARY KEY("type", "name")
    ) WITHOUT ROWID
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE tag_statistics
  STR
end
