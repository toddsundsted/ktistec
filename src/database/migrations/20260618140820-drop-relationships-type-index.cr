require "../../framework/database"

extend Ktistec::Database::Migration

# `idx_relationships_type` is redundant. no production query reads
# `relationships` by `type` without also constraining `from_iri` or
# `to_iri`. the only remaining `type`-only consumers are the one-time
# reconcile migration's `COUNT`/`DELETE`, which run before this
# migration and so still have the index available.

up do |db|
  db.exec <<-STR
    DROP INDEX IF EXISTS idx_relationships_type
  STR
end

down do |db|
  db.exec <<-STR
    CREATE INDEX IF NOT EXISTS idx_relationships_type
      ON relationships (type ASC)
  STR
end
