require "../../framework/database"

extend Ktistec::Database::Migration

# `1` is a snapshot of `Feed::Backend::Criteria::REVISION`

up do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_feed_versions_owner_iri_backend_params
  STR
  add_column "feed_versions", "revision", "varchar(63) NOT NULL DEFAULT \"\""
  db.exec <<-STR
    UPDATE feed_versions SET revision = '1' WHERE backend = 'criteria'
  STR
  db.exec <<-STR
    CREATE UNIQUE INDEX idx_feed_versions_owner_iri_backend_params_revision
      ON feed_versions (owner_iri ASC, backend ASC, params ASC, revision ASC)
  STR
end

down do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_feed_versions_owner_iri_backend_params_revision
  STR
  remove_column "feed_versions", "revision"
  db.exec <<-STR
    CREATE UNIQUE INDEX IF NOT EXISTS idx_feed_versions_owner_iri_backend_params
      ON feed_versions (owner_iri ASC, backend ASC, params ASC)
  STR
end
