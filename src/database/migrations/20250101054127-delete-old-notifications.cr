require "../../framework/database"

# Migration 20240212125448 was incorrect. It was also one way. Delete
# the record of the old migration and rerun the intended migration.
# See: https://github.com/toddsundsted/ktistec/commit/69e2fe66dfa28077438ae8cfe4afc85b3ee09b5c

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DELETE FROM migrations WHERE id = 20240212125448;
  STR
  db.exec <<-STR
    DELETE FROM relationships
    WHERE type IN ("Relationship::Content::Notification::Hashtag", "Relationship::Content::Notification::Thread")
  STR
  db.exec <<-STR
    DELETE FROM relationships
    WHERE type = "Relationship::Content::Notification::Mention"
    AND to_iri NOT IN (
      SELECT to_iri FROM relationships
      JOIN objects ON objects.iri = relationships.to_iri
      JOIN tags ON tags.subject_iri = objects.iri
      JOIN accounts ON accounts.iri = tags.href
      WHERE relationships.type = "Relationship::Content::Notification::Mention"
      AND tags.type = "Tag::Mention"
    )
  STR
end
