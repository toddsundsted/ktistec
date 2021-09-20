require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    ALTER TABLE accounts ADD COLUMN state text
  STR
end

down do |db|
  db.exec <<-STR
    CREATE TABLE accounts_new (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      username varchar(255) NOT NULL,
      encrypted_password varchar(255) NOT NULL,
      iri varchar(255) NOT NULL COLLATE NOCASE,
      timezone varchar(244) NOT NULL DEFAULT ""
    )
  STR
  db.exec <<-STR
    INSERT INTO accounts_new SELECT id, created_at, updated_at, username, encrypted_password, iri, timezone FROM accounts
  STR
  db.exec <<-STR
    DROP TABLE accounts
  STR
  db.exec <<-STR
    ALTER TABLE accounts_new RENAME TO accounts
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_accounts_username
      ON accounts (username ASC)
  STR
end
