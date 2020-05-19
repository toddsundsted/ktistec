require "../../framework/database"

extend Balloon::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE actors (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      type varchar(32) NOT NULL,
      aid varchar(255) NOT NULL,
      username varchar(255),
      pem_public_key text,
      pem_private_key text,
      inbox text,
      outbox text,
      following text,
      followers text,
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
end

down do |db|
  db.exec <<-STR
    DROP TABLE actors;
  STR
end
