require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    CREATE TABLE quote_decisions (
      "id" integer PRIMARY KEY AUTOINCREMENT,
      "quote_authorization_iri" text COLLATE NOCASE NOT NULL,
      "interacting_object_iri" text COLLATE NOCASE,
      "interaction_target_iri" text COLLATE NOCASE,
      "decision" text NOT NULL DEFAULT 'accept',
      "created_at" datetime NOT NULL,
      "updated_at" datetime NOT NULL
    )
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_quote_decisions_quote_authorization_iri
      ON quote_decisions (quote_authorization_iri)
  STR
  db.exec <<-STR
    CREATE INDEX idx_quote_decisions_interaction_target_iri_interacting_object_iri
      ON quote_decisions (interaction_target_iri, interacting_object_iri)
  STR
  db.exec <<-STR
    CREATE INDEX idx_quote_decisions_interacting_object_iri
      ON quote_decisions (interacting_object_iri)
  STR
end

down do |db|
  db.exec <<-STR
    DROP TABLE quote_decisions
  STR
end
