require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_tags_type_subject_iri
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_tags_type_name
  STR

  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_tags_subject_iri
      ON tags (subject_iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_tags_name
      ON tags (name ASC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_tags_mention_href
      ON tags (href ASC)
      WHERE type = 'Tag::Mention'
  STR

  db.exec <<-STR
    ANALYZE tags
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_tags_subject_iri
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_tags_name
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_tags_mention_href
  STR

  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_tags_type_subject_iri
      ON tags (type ASC, subject_iri ASC)
  STR
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_tags_type_name
      ON tags (type ASC, name ASC)
  STR

  db.exec <<-STR
    ANALYZE tags
  STR
end
