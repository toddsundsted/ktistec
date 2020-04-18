require "../../framework/database"

extend Balloon::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE actors (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      username varchar(255) NOT NULL,
      encrypted_password varchar(255) NOT NULL,
      pem_public_key text NOT NULL,
      pem_private_key text NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_actors_username
      ON actors (username ASC)
  STR
  db.exec <<-STR
    CREATE TRIGGER trg_actors_updated_at
    AFTER UPDATE
    ON actors FOR EACH ROW
    BEGIN
      UPDATE actors SET updated_at = current_timestamp
        WHERE id = old.id;
    END
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE actors;
  STR
end
