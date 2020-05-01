require "../../framework/database"

extend Balloon::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE actors (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      type varchar(32) NOT NULL,
      aid varchar(255),
      username varchar(255),
      pem_public_key text,
      pem_private_key text,
      name text,
      summary text,
      icon text,
      image text
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_actors_aid
      ON actors (aid ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_actors_username
      ON actors (username ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE actors;
  STR
end
