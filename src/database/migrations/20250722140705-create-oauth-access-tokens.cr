require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE oauth_access_tokens (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL,
      "token" varchar(255) NOT NULL,
      "client_id" integer NOT NULL,
      "account_id" integer NOT NULL,
      "expires_at" datetime NOT NULL,
      "scope" varchar(255) NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_oauth_access_tokens_token
      ON oauth_access_tokens (token ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_oauth_access_tokens_client_id
      ON oauth_access_tokens (client_id ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_oauth_access_tokens_account_id
      ON oauth_access_tokens (account_id ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE oauth_access_tokens
  STR
end
