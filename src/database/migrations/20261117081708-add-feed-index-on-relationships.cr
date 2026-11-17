require "../../framework/database"

extend Ktistec::Database::Migration

# Partial index serving the feed read (`Feed#contents`).
#
# Feed rows carry a synthetic per-feed type (`Feed::<id>`), which the
# read binds as a parameter, so the read must also repeat the `WHERE`
# predicate (`Feed.type_predicate`) for the partial index to bind.

up do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_relationships_feed_from_iri_type_created_at
      ON relationships (from_iri ASC, type ASC, created_at DESC, id DESC)
      WHERE substr(type, 1, 6) = 'Feed::'
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_relationships_feed_from_iri_type_created_at
  STR
end
