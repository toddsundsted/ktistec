require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DELETE FROM relationships
    WHERE type IN ("Relationship::Content::Notification::Hashtag", "Relationship::Content::Notification::Threadx")
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
