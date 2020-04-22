require "../../framework/database"

extend Balloon::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE sessions (
      id integer PRIMARY KEY AUTOINCREMENT,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      body_json text NOT NULL,
      session_key varchar(22) NOT NULL,
      actor_id integer NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_sessions_session_key
      ON sessions (session_key ASC)
  STR
  db.exec <<-STR
    CREATE INDEX idx_sessions_actor_id
      ON sessions (actor_id ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE sessions;
  STR
end
