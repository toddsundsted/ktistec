require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE oauth_clients (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "client_id" varchar(255) NOT NULL,
      "client_secret" varchar(255) NOT NULL,
      "client_name" varchar(255) NOT NULL,
      "redirect_uris" text NOT NULL,
      "scope" varchar(255) NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_oauth_clients_client_id
      ON oauth_clients (client_id ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE oauth_clients
  STR
end
