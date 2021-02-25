require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE accounts (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      username varchar(255) NOT NULL,
      encrypted_password varchar(255) NOT NULL,
      iri varchar(255) NOT NULL COLLATE NOCASE
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_accounts_username
      ON accounts (username ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE accounts;
  STR
end
