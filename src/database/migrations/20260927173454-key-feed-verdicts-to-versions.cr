require "../../framework/database"

extend Ktistec::Database::Migration

up do |db|
  add_column "feed_verdicts", "version_id", "integer"
  db.exec <<-STR
    UPDATE feed_verdicts
       SET version_id = (SELECT f.version_id FROM feeds f WHERE f.id = feed_verdicts.feed_id)
  STR
  db.exec <<-STR
    DELETE FROM feed_verdicts
     WHERE version_id IS NULL
  STR
  db.exec <<-STR
    DELETE FROM feed_verdicts
     WHERE id NOT IN (
       SELECT id FROM (
         SELECT id, ROW_NUMBER() OVER (PARTITION BY version_id, object_iri ORDER BY updated_at DESC, id DESC) AS rn
           FROM feed_verdicts
       ) WHERE rn = 1
     )
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_feed_verdicts_feed_id_object_iri
  STR
  remove_column "feed_verdicts", "feed_id"
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_feed_verdicts_version_id_object_iri
      ON feed_verdicts (version_id ASC, object_iri ASC)
  STR
  remove_column "feed_verdicts", "position"
end

down do |db|
  add_column "feed_verdicts", "position", "datetime NOT NULL DEFAULT '1970-01-01 00:00:00.000'"
  db.exec <<-STR
    UPDATE feed_verdicts
       SET position = COALESCE((SELECT o.created_at FROM objects o WHERE o.iri = feed_verdicts.object_iri), created_at)
  STR
  add_column "feed_verdicts", "feed_id", "integer"
  db.exec <<-STR
    INSERT INTO feed_verdicts (created_at, updated_at, feed_id, object_iri, included, reason, position, version_id)
    SELECT v.created_at, v.updated_at, f.id, v.object_iri, v.included, v.reason, v.position, NULL
      FROM feed_verdicts v
      JOIN feeds f ON f.version_id = v.version_id
  STR
  db.exec <<-STR
    DELETE FROM feed_verdicts
     WHERE feed_id IS NULL
  STR
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_feed_verdicts_version_id_object_iri
  STR
  remove_column "feed_verdicts", "version_id"
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_feed_verdicts_feed_id_object_iri
      ON feed_verdicts (feed_id ASC, object_iri ASC)
  STR
end
