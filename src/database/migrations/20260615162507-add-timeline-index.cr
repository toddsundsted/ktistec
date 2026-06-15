require "../../framework/database"

extend Ktistec::Database::Migration

# Partial index serving the authenticated timeline read.
#
# The `WHERE` predicate must stay byte-for-byte identical to
# `Relationship::Content::Timeline.type_in_list` (the `type IN (...)`
# list the read query interpolates) so the partial index binds.

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_relationships_timeline_from_iri_created_at
      ON relationships (from_iri ASC, created_at DESC)
      WHERE type IN ('Relationship::Content::Timeline::Announce','Relationship::Content::Timeline::Create')
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_relationships_timeline_from_iri_created_at
  STR
end
